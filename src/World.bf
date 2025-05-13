using System;
using System.Collections;
namespace tecs;

public sealed class World : IDisposable
{
	private readonly SparseSet<EcsRecord> _entities = new .() ~ { _.Clear(); delete _; };
	private readonly Dictionary<uint64, Archetype> _typeIndex = new .() ~ DeleteDictionaryAndValues!(_);
	private uint64 _lastArchetypeId;

	private static readonly ComponentInfo[] _emptyComponents = new .() ~ delete _;

	public this()
	{
		_typeIndex.Add(Root.Id, Root);
		_lastArchetypeId = Root.Id;
	}


	public Archetype Root { get; } = new .(this, _emptyComponents);



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

	public void Dispose()
	{
	}


	private ref EcsRecord NewRecord(out uint64 newId, uint64 id = 0)
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

	public ref EcsRecord GetRecord(uint64 id)
	{
		if (_entities.Get(id) case .Ok(let record))
		{
			return ref *record;
		}

		var str = scope String();
		str..AppendF("entity {} is dead or doesn't exist anymore!", id);
		Runtime.FatalError(str);
	}
}

struct EcsRecord
{
	public Archetype Archetype;
	public ArchetypeChunk Chunk;
	public int Row;
}