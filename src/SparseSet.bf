using System.Collections;
using System;
namespace tecs;

public sealed class SparseSet<T>
{
	const int CHUNK_SIZE = 4096;

	private Chunk[] _chunks;
	private int _count;
	private uint64 _maxId;
	private readonly List<uint64> _dense;

	public this()
	{
		_dense = new .();
		_chunks = new Chunk[0];
		_count = 1;
		_maxId = uint64.MinValue;

		_dense.Add(0);
	}

	public ~this()
	{
		for (var chunk in ref _chunks)
		{
			delete chunk.Sparse;
			delete chunk.Values;
		}

		delete _chunks;
		delete _dense;
	}

	public int Length => _count - 1;

	public ref uint64 MaxId => ref _maxId;

	public Result<T*> CreateNew(out uint64 id)
	{
		let count = _count++;
		let denseCount = _dense.Count;

		id = count < denseCount ? _dense[count] : NewId(count);

		if (GetChunk((int32)id >> 12) case .Ok(var chunk))
			return .Ok(&chunk.Values[(int32)id & 0xFFF]);

		return .Err;
	}

	public Result<T*> Get(uint64 outerIdx)
	{
		if (GetChunk((int32)outerIdx >> 12) case .Ok(let chunk))
		{
			if (chunk.Sparse == null)
				return .Err;

			let realId = (int32)outerIdx & 0xFFF;
			let dense = chunk.Sparse[realId];

			if (dense == 0 || dense >= _count)
				return .Err;

			var outerIdx;
			let gen = SplitGeneration(ref outerIdx);
			let curGen = _dense[dense] & EcsConst.ECS_GENERATION_MASK;
			if (gen != curGen)
				return .Err;

			return .Ok(&chunk.Values[realId]);
		}

		return .Err;
	}

	public bool Contains(uint64 outerIdx)
	{
		let chunk = ref GetChunkOrCreate((int32)outerIdx >> 12);
		if (chunk.Sparse == null)
			return false;

		let realId = (int32)outerIdx & 0xFFF;
		let dense = chunk.Sparse[realId];
		if (dense == 0 || dense >= _count)
			return false;

		var outerIdx;
		let gen = SplitGeneration(ref outerIdx);
		let curGen = _dense[dense] & EcsConst.ECS_GENERATION_MASK;
		if (gen != curGen)
			return false;

		return true;
	}

	public ref T Add(uint64 outerIdx, T value)
	{
		var outerIdx;
		let gen = SplitGeneration(ref outerIdx);
		let realId = (int32)outerIdx & 0xFFF;
		var chunk = ref GetChunkOrCreate((int32)outerIdx >> 12);
		var dense = chunk.Sparse[realId];

		if (dense != 0)
		{
			let count = _count;
			if (dense >= count)
			{
				SwapDense(ref chunk, dense, count);
				dense = count;
				_count += 1;
			}
		}
		else
		{
			_dense.Add(0);

			let denseCount = _dense.Count - 1;
			let count = _count++;

			if (outerIdx >= _maxId)
			{
				_maxId = outerIdx;
			}

			if (count < denseCount)
			{
				let unused = _dense[count];
				var unusedChunk = ref GetChunkOrCreate((int32)unused >> 12);
				SparseAssignIndex(ref unusedChunk, unused, denseCount);
			}

			SparseAssignIndex(ref chunk, outerIdx, count);
			_dense[count] |= gen;
		}

		chunk.Values[realId] = value;
		return ref chunk.Values[realId];
	}

	public void Remove(uint64 outerIdx)
	{
		if (GetChunk((int32)outerIdx >> 12) case .Ok(var chunk))
		{
			var outerIdx;
			let gen = SplitGeneration(ref outerIdx);
			let realId = (int32)outerIdx & 0xFFF;
			let dense = chunk.Sparse[realId];

			if (dense == 0)
				return;

			let curGen = _dense[dense] & EcsConst.ECS_GENERATION_MASK;
			if (gen != curGen)
				return;

			_dense[dense] = outerIdx | EcsOp.IncreaseGeneration(curGen);

			let count = _count;
			if (dense == (count - 1))
				_count--;
			else if (dense < count)
			{
				SwapDense(ref *chunk, dense, count - 1);
				_count--;
			}
			else
			{
				return;
			}

			chunk.Values[realId] = default;
		}
	}

	public void Clear()
	{
		if (_count <= 1)
			return;

		_maxId = uint64.MinValue;

		_dense.Clear();
		_dense.Add(0);
		_count = 1;
	}

	private uint64 NewId(int dense)
	{
		let index = ++_maxId;
		_dense.Add(0);

		var chunk = ref GetChunkOrCreate((int32)index >> 12);
		SparseAssignIndex(ref chunk, index, dense);

		return index;
	}

	private static uint64 SplitGeneration(ref uint64 index)
	{
		let gen = index & EcsConst.ECS_GENERATION_MASK;
		index -= gen;
		return gen;
	}

	private void SwapDense(ref Chunk chunkA, int a, int b)
	{
		let idxA = _dense[a];
		let idxB = _dense[b];

		var chunkB = ref GetChunkOrCreate((int32)idxB >> 12);
		SparseAssignIndex(ref chunkA, idxA, b);
		SparseAssignIndex(ref chunkB, idxB, a);
	}

	private void SparseAssignIndex(ref Chunk chunk, uint64 index, int dense)
	{
		chunk.Sparse[(int32)index & 0xFFF] = dense;
		_dense[dense] = index;
	}

	private Result<Chunk*> GetChunk(int index)
		=> (index >= _chunks.Count ? .Err : .Ok(&_chunks[index]));

	private ref Chunk GetChunkOrCreate(int index)
	{
		if (index >= _chunks.Count)
		{
			let oldLength = _chunks.Count;
			var newLength = oldLength > 0 ? oldLength << 1 : 2;
			while (index >= newLength)
				newLength <<= 1;

			let oldChunks = _chunks;
			let newChunks = new Chunk[newLength];
			oldChunks.CopyTo(newChunks);
			_chunks = newChunks;

			delete oldChunks;
		}

		var chunk = ref _chunks[index];
		if (chunk.Sparse == null)
		{
			chunk.Sparse = new int[CHUNK_SIZE];
			chunk.Values = new T[CHUNK_SIZE];
		}

		return ref chunk;
	}


	private struct Chunk
	{
		public int[] Sparse;
		public T[] Values;
	}
}