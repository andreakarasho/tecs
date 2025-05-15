using System;
using System.Collections;
namespace tecs;

using internal tecs;

public sealed class World : IDisposable
{
	private readonly SparseSet<Record> _entities = new .() ~ { _.Clear(); delete _; };
	private readonly Dictionary<uint64, Archetype> _typeIndex = new .() ~ DeleteDictionaryAndValues!(_);
	private uint64 _lastArchetypeId;
	private uint32 _ticks;

	private static readonly Comparison<ComponentInfo> _componentComparer = new => CompareComponents ~ delete _;

	public this()
	{
		_typeIndex.Add(Root.Id, Root);
		_lastArchetypeId = Root.Id;
	}


	public Archetype Root { get; } = new .(this, new .());
	internal uint64 LastArchetypeId => _lastArchetypeId;


	public uint64 Entity(uint64 id = 0)
	{
		var id;
		if (id == 0 || !Exists(id))
		{
			var record = ref NewRecord(out id);
			record.Archetype = Root;
			record.Chunk = Root.Add(id, out record.Row);
		}

		return id;
	}

	public bool Exists(uint64 id)
	{
		return _entities.Contains(id);
	}

	public void Delete(uint64 id)
	{
		var record = ref GetRecord(id);
		let removedId = record.Archetype.Remove(ref record);
		_entities.Remove(removedId);
	}

	public void Add<T>(uint64 id) where T : struct
	{
		let meta = ref Component<T>();
		Attach(id, meta.Id, 0);
	}

	public void Set<T>(uint64 id, T component) where T : struct
	{
		let meta = ref Component<T>();

		var (raw, row) = Attach(id, meta.Id, meta.Size);
		var array = (T*)raw;
		array[row & Archetype.CHUNK_THRESHOLD] = component;
	}

	public void Unset<T>(uint64 id) where T : struct
	{
		let meta = ref Component<T>();
		Detach(id, meta.Id);
	}

	public ref T Get<T>(uint64 id) where T : struct
	{
		let meta = ref Component<T>();
		let record = ref GetRecord(id);
		let column = record.Archetype.GetComponentIndex(meta.Id);
		return ref record.Chunk.GetReferenceAt<T>(column, record.Row);
	}

	public bool Has<T>(uint64 id) where T : struct
	{
		let meta = ref Component<T>();
		var record = ref GetRecord(id);
		return IsAttached(ref record, meta.Id);
	}

	public readonly ref ComponentInfo Component<T>() where T : struct
	{
		return ref Lookup.Component<T>.Value;
	}

	public QueryBuilder QueryBuilder() => new QueryBuilder(this);

	public void BeginDeferred() { }

	public void EndDeferred() { }


	public void Dispose()
	{
	}



	private (uint8*, int) Attach(uint64 id, uint64 cmp, int32 size)
	{
		var record = ref GetRecord(id);
		let oldArch = record.Archetype;

		var column = size > 0 ? oldArch.GetComponentIndex(cmp) : oldArch.GetAnyIndex(cmp);
		if (column >= 0)
		{
			if (size > 0)
			{
				record.Chunk.MarkChanged(column, record.Row, _ticks);
			}

			return (size > 0 ? record.Chunk.Columns[column].Data : null, record.Row);
		}

		BeginDeferred();

		var foundArch = oldArch.TraverseRight(cmp);
		if (foundArch == null)
		{
			var hash = 0UL;
			var found = false;

			for (let c in ref oldArch.Components)
			{
				if (!found && c.Id > cmp)
				{
					hash = NiceHash.Combine(hash, cmp);
					found = true;
				}

				hash = NiceHash.Combine(hash, c.Id);
			}

			if (!found)
				hash = NiceHash.Combine(hash, cmp);

			if (!_typeIndex.TryGetValue(hash, out foundArch))
			{
				var arr = new ComponentInfo[oldArch.Components.Count + 1];
				oldArch.Components.CopyTo(arr, 0);
				arr[^1] = .(cmp, size);
				Array.Sort(arr, _componentComparer);
				foundArch = NewArchetype(oldArch, arr, cmp);
			}
		}

		record.Chunk = record.Archetype.MoveEntity(foundArch, ref record.Chunk, record.Row, false, out record.Row);
		record.Archetype = foundArch;

		EndDeferred();

		column = size > 0 ? foundArch.GetComponentIndex(cmp) : foundArch.GetAnyIndex(cmp);
		if (size > 0)
		{
			record.Chunk.MarkAdded(column, record.Row, _ticks);
		}

		return (size > 0 ? record.Chunk.Columns[column].Data : null, record.Row);
	}

	private void Detach(uint64 id, uint64 cmp)
	{
		var record = ref GetRecord(id);
		let oldArch = record.Archetype;

		if (oldArch.GetAnyIndex(cmp) < 0)
			return;

		BeginDeferred();

		var foundArch = oldArch.TraverseLeft(cmp);
		if (foundArch == null && oldArch.Components.Count - 1 <= 0)
		{
			foundArch = Root;
		}

		if (foundArch == null)
		{
			var hash = 0UL;

			for (var c in ref oldArch.Components)
			{
				if (c.Id != cmp)
					hash = NiceHash.Combine(hash, c.Id);
			}

			if (!_typeIndex.TryGetValue(hash, out foundArch))
			{
				var arr = new ComponentInfo[oldArch.Components.Count - 1];
				for (var i = 0, j = 0; i < oldArch.Components.Count; ++i)
				{
					if (oldArch.Components[i].Id != cmp)
					{
						arr[j++] = oldArch.Components[i];
					}
				}

				foundArch = NewArchetype(oldArch, arr, cmp);
			}
		}

		record.Chunk = record.Archetype.MoveEntity(foundArch, ref record.Chunk, record.Row, true, out record.Row);
		record.Archetype = foundArch;

		EndDeferred();
	}

	private bool IsAttached(ref Record record, uint64 id)
		=> record.Archetype.HasIndex(id);

	private Archetype NewArchetype(Archetype oldArch, ComponentInfo[] sign, uint64 id)
	{
		var archetype = Root.InsertVertex(oldArch, sign, id);
		_typeIndex.Add(archetype.Id, archetype);
		_lastArchetypeId = archetype.Id;
		return archetype;
	}

	private ref Record NewRecord(out uint64 newId, uint64 id = 0)
	{
		if (id > 0)
		{
			newId = id;
			return ref _entities.Add(id, default);
		}

		if (_entities.CreateNew(out newId) case .Ok(let record))
		{
			return ref *record;
		}

		Runtime.FatalError("error on creating a new record!");
	}

	internal ref Record GetRecord(uint64 id)
	{
		if (_entities.Get(id) case .Ok(let record))
		{
			return ref *record;
		}

		var str = scope String();
		str..AppendF("entity {} is dead or doesn't exist anymore!", id);
		Runtime.FatalError(str);
	}


	private static int CompareComponents(ComponentInfo a, ComponentInfo b) => a.Id <=> b.Id;
}

internal struct Record
{
	public Archetype Archetype;
	public ArchetypeChunk Chunk;
	public int Row;
}