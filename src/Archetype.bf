using System;
using System.Collections;
namespace tecs;

public class Archetype
{
	const int ARCHETYPE_INITIAL_CAPACITY = 1;

	internal const int CHUNK_SIZE = 4096;
	public const int CHUNK_LOG2 = 12;
	public const int CHUNK_THRESHOLD = CHUNK_SIZE - 1;

	private readonly List<Edge> _add, _remove;
	private readonly Dictionary<uint64, int> _lookupAny, _lookupComponents;
	private int _count;
	private ArchetypeChunk[] _chunks;


	public this(World world, ComponentInfo[] sign)
	{
		World = world;
		Components = sign;

		var hash = 0UL;
		var dict = new Dictionary<uint64, int>();
		var allDict = new Dictionary<uint64, int>();
		var maxId = -1;

		for (var i = 0, cur = 0; i < sign.Count; ++i)
		{
			hash = NiceHash.Combine(hash, sign[i].Id);

			if (sign[i].Size > 0)
			{
				dict.Add(sign[i].Id, cur++);
				maxId = Math.Max(maxId, (int32)sign[i].Id);
			}

			allDict.Add(sign[i].Id, i);
		}

		Id = hash;

		_lookupAny = allDict;
		_lookupComponents = dict;

		_add = new .();
		_remove = new .();
		_chunks = new ArchetypeChunk[ARCHETYPE_INITIAL_CAPACITY];
	}

	public ~this()
	{
		for (var chunk in ref _chunks)
			delete chunk;
		delete _chunks;

		_add.Clear();
		delete _add;

		_remove.Clear();
		delete _remove;

		_lookupComponents.Clear();
		delete _lookupComponents;

		_lookupAny.Clear();
		delete _lookupAny;

		delete Components;
	}

	public ComponentInfo[] Components { get; }
	public World World { get; }
	public uint64 Id { get; }
	public int Count => _count;
	public readonly Span<ArchetypeChunk> Chunks => .(_chunks, 0, (_count + CHUNK_SIZE - 1) >> CHUNK_LOG2);
	public int EmptyChunks => _chunks.Count - ((_count + CHUNK_SIZE - 1) >> CHUNK_LOG2);


	public ref ArchetypeChunk GetOrCreateChunk(int index)
	{
		var index;
		index >>= CHUNK_LOG2;

		if (index >= _chunks.Count)
		{
			var oldChunks = _chunks;
			var newChunks = new ArchetypeChunk[Math.Max(ARCHETYPE_INITIAL_CAPACITY, oldChunks.Count * 2)];
			oldChunks.CopyTo(newChunks);
			_chunks = newChunks;

			delete oldChunks;
		}

		var chunk = ref _chunks[index];
		if (chunk == null || chunk.Columns == null)
			chunk = new ArchetypeChunk(.(Components), CHUNK_SIZE);

		return ref chunk;
	}

	public ref ArchetypeChunk GetChunk(int index)
		=> ref _chunks[index >> CHUNK_LOG2];

	public int GetComponentIndex(uint64 id)
		=> _lookupComponents.TryGetValue(id, let val) ? val : -1;

	public int GetAnyIndex(uint64 id)
		=> _lookupAny.TryGetValue(id, let val) ? val : -1;

	public bool HasIndex(uint64 id)
		=> _lookupAny.ContainsKey(id);

	public ref ArchetypeChunk Add(uint64 id, out int row)
	{
		var chunk = ref GetOrCreateChunk(_count);
		chunk.GetEntityAt(chunk.Count++) = id;
		row = _count++;
		return ref chunk;
	}

	public uint64 Remove(ref EcsRecord record)
		=> RemoveByRow(ref record.Chunk, record.Row);

	public Archetype InsertVertex(Archetype left, ComponentInfo[] sign, uint64 id)
	{
		var vertex = new Archetype(left.World, sign);
		let a = left.Components.Count < vertex.Components.Count ? left : vertex;
		let b = left.Components.Count < vertex.Components.Count ? vertex : left;

		MakeEdges(a, b, id);
		InsertVertex(vertex);
		return vertex;
	}

	public ref ArchetypeChunk MoveEntity(Archetype newArch, ref ArchetypeChunk fromChunk, int oldRow, bool isRemove, out int newRow)
	{
		var toChunk = ref newArch.Add(fromChunk.GetEntityAt(oldRow), out newRow);

		var i = 0, j = 0;
		let count = isRemove ? newArch.Components.Count : Components.Count;

		var x = (isRemove ? &j : &i);
		var y = (!isRemove ? &j : &i);

		let srcIdx = oldRow & CHUNK_THRESHOLD;
		let dstIdx = newRow & CHUNK_THRESHOLD;

		let items = Components;
		let newItems = newArch.Components;

		for (; *x < count; (*x)++,(*y)++)
		{
			while (items[i].Id != newItems[j].Id)
			{
				(*y)++;
			}

			fromChunk.Columns[i].CopyTo(srcIdx, ref toChunk.Columns[j], dstIdx);
		}

		RemoveByRow(ref fromChunk, oldRow);

		return ref toChunk;
	}

	public void GetSuperSets(Span<IQueryTerm> terms, List<Archetype> matched)
	{
		let result = FileterMatch.Match(this, terms);

		if (result == .Stop)
			return;

		if (result == .Found)
			matched.Add(this);

		if (_add.Count <= 0)
			return;

		for (let edge in ref _add)
			edge.Archetype.GetSuperSets(terms, matched);
	}

	public Archetype TraverseLeft(uint64 nodeId)
		=> Traverse(this, nodeId, false);

	public Archetype TraverseRight(uint64 nodeId)
		=> Traverse(this, nodeId, true);

	private static Archetype Traverse(Archetype root, uint64 nodeId, bool onAdd)
	{
		for (let edge in ref (onAdd ? root._add : root._remove))
		{
			if (edge.Id == nodeId)
				return edge.Archetype;
		}

		return null;
	}

	private uint64 RemoveByRow(ref ArchetypeChunk chunk, int row)
	{
		_count -= 1;

		var lastChunk = ref GetChunk(_count);
		let removed = chunk.GetEntityAt(row);

		if (row < _count)
		{
			chunk.GetEntityAt(row) = lastChunk.GetEntityAt(_count);

			let srcIdx = _count & CHUNK_THRESHOLD;
			let dstIdx = row & CHUNK_THRESHOLD;

			for (var i < Components.Count)
				lastChunk.Columns[i].CopyTo(srcIdx, ref chunk.Columns[i], dstIdx);

			var rec = ref World.GetRecord(chunk.GetEntityAt(row));
			rec.Row = row;
			rec.Chunk = chunk;
		}

		lastChunk.Count -= 1;
		return removed;
	}

	private void InsertVertex(Archetype newNode)
	{
		let nodeTypeLength = Components.Count;
		let newTypeLength = newNode.Components.Count;

		if (nodeTypeLength < newTypeLength - 1)
		{
			for (var edge in ref _add)
				edge.Archetype.InsertVertex(newNode);

			return;
		}

		if (!IsSuperSet(newNode.Components))
			return;

		var i = 0;
		var newNodeTypeLen = newNode.Components.Count;
		for (; i < newNodeTypeLen && Components[i].Id == newNode.Components[i].Id; ++i) { }

		MakeEdges(newNode, this, Components[i].Id);
	}

	private bool IsSuperSet(ComponentInfo[] other)
	{
		var i = 0;
		var j = 0;

		while (i < Components.Count && j < other.Count)
		{
			if (Components[i].Id == other[j].Id)
			{
				j++;
			}

			i++;
		}

		return j == other.Count;
	}

	private static void MakeEdges(Archetype left, Archetype right, uint64 id)
	{
		left._add.Add(Edge { Archetype = right, Id = id });
		right._remove.Add(Edge { Archetype = left, Id = id });
	}
}

public struct Column
{
	public readonly void* Data;
	public readonly int DataSize;
	public uint[] ChangedTicks, AddedTicks;

	public this(ComponentInfo componentInfo, int chunkSize)
	{
		Data = Internal.StdMalloc(componentInfo.Size * chunkSize);
		DataSize = componentInfo.Size;
		ChangedTicks = new uint[chunkSize];
		AddedTicks = new uint[chunkSize];
	}

	public void MarkChanged(int index, uint ticks)
	{
		ChangedTicks[index] = ticks;
	}

	public void MarkAdded(int index, uint ticks)
	{
		AddedTicks[index] = ticks;
	}

	public void CopyTo(int srcIdx, ref Column dest, int dstIdx)
	{
		Internal.MemCpy(
			(uint8*)dest.Data + dstIdx * DataSize,
			(uint8*)Data + srcIdx * DataSize,
			DataSize);
		dest.ChangedTicks[dstIdx] = ChangedTicks[srcIdx];
		dest.AddedTicks[dstIdx] = AddedTicks[srcIdx];
	}
}

public class ArchetypeChunk
{
	public readonly Column[] Columns;
	public readonly uint64[] Entities;

	public this(Span<ComponentInfo> sign, int chunkSize)
	{
		Entities = new uint64[chunkSize];
		Columns = new Column[sign.Length];

		for (var i < sign.Length)
			Columns[i] = .(sign[i], chunkSize);
	}

	public ~this()
	{
		for (var col in ref Columns)
		{
			Internal.StdFree(col.Data);
			delete col.AddedTicks;
			delete col.ChangedTicks;
		}
		delete Columns;
		delete Entities;
	}


	public int Count { get; set; } = 0;


	[Inline]
	public Result<Column*> GetColumn(int column)
	{
		if (column < 0 || column >= Columns.Count)
			return .Err;

		return .Ok(&Columns[column]);
	}

	[Inline]
	public ref T GetReferenceAt<T>(int column, int row) where T : struct
	{
		if (column < 0 || column > Columns.Count)
			return ref (*(T*)null);

		let data = (T*)Columns[column].Data;
		return ref data[row & Archetype.CHUNK_THRESHOLD];
	}

	[Inline]
	public Span<T> GetSpan<T>(int column) where T : struct
	{
		if (column < 0 || column >= Columns.Count)
			return .();

		let data = (T*)Columns[column].Data;
		return .(data, Count);
	}

	[Inline]
	public Span<uint64> GetEntities()
	{
		return .(Entities, 0, Count);
	}

	[Inline]
	public ref uint64 GetEntityAt(int row)
		=> ref Entities[row & Archetype.CHUNK_THRESHOLD];
}

public struct Edge
{
	public uint64 Id;
	public Archetype Archetype;
}

public struct ComponentInfo
{
	public this(uint64 id, int size)
	{
		Id = id;
		Size = size;
	}

	public readonly uint64 Id;
	public readonly int Size;
}