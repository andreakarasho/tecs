using System;
using System.Collections;
namespace tecs;

using internal tecs;

public sealed class Query
{
	private static readonly Comparison<IQueryTerm> _termComparer = new => CompareTerms ~ delete _;

	private readonly IQueryTerm[] _terms ~ delete _;
	private readonly List<Archetype> _matcherArchetypes = new .() ~ { _.Clear(); delete _; };
	private readonly int[] _indices ~ delete _;
	private uint64 _lastArchetypeMatched;

	public this(World world, params IQueryTerm[] terms)
	{
		World = world;
		_terms = new IQueryTerm[terms.Count];
		terms.CopyTo(_terms);
		Array.Sort(_terms, _termComparer);

		for (let term in ref terms)
		{
			if (Lookup.GetComponent(term.Id()).Size > 0)
				TermAccess.Add(term);
		}

		_indices = new int[TermAccess.Count];
		_indices.SetAll(-1);
	}

	public World World { get; }
	public List<IQueryTerm> TermAccess { get; } = new .() ~ { _.Clear(); delete _; }


	private void Match()
	{
		if (_lastArchetypeMatched == World.LastArchetypeId)
			return;

		_lastArchetypeMatched = World.LastArchetypeId;
		_matcherArchetypes.Clear();
		World.Root.GetSuperSets(_terms, _matcherArchetypes);
	}

	public QueryIterator Iter()
	{
		Match();

		return .(World, _matcherArchetypes, TermAccess, _indices, 0, 0);
	}

	private static int CompareTerms(IQueryTerm a, IQueryTerm b) => a.Id() <=> b.Id();
}

public class QueryBuilder
{
	private readonly World _world;
	private readonly Dictionary<uint64, IQueryTerm> _terms = new .() ~ { _.Clear(); delete _; };
	private Query _query;

	internal this(World world)
	{
		_world = world;
	}


	public Self With<T>(uint64 id) where T : struct
		=> With(_world.Component<T>().Id);

	public Self With(uint64 id)
		=> Term(WithTerm(id));

	public Self Without<T>(uint64 id) where T : struct
		=> Without(_world.Component<T>().Id);

	public Self Without(uint64 id)
		=> Term(WithoutTerm(id));

	public Self Optional<T>(uint64 id) where T : struct
		=> Optional(_world.Component<T>().Id);

	public Self Optional(uint64 id)
		=> Term(OptionalTerm(id));

	public Self Term(IQueryTerm term)
	{
		_terms[term.Id()] = term;
		return this;
	}

	public Query Build()
	{
		if (_query != null)
		{
			delete _query;
			_query = null;
		}

		var tmp = scope IQueryTerm[_terms.Count];
		var i = 0;
		for (var c in _terms.Values)
			tmp[i++] = c;

		_query ??= new .(_world, params tmp);
		return _query;
	}
}

public struct QueryIterator
{
	private Span<Archetype>.Enumerator _archetypeEnumerator;
	private Span<ArchetypeChunk>.Enumerator _chunkEnumerator;
	private readonly Span<IQueryTerm> _terms;
	private readonly Span<int> _indices;
	private readonly int _start, _startSafe, _count;

	public this(World world, Span<Archetype> archetypes, Span<IQueryTerm> terms, Span<int> indices, int start, int count)
	{
		World = world;
		_archetypeEnumerator = archetypes.GetEnumerator();
		_terms = terms;
		_indices = indices;
		_start = start;
		_startSafe = start & Archetype.CHUNK_THRESHOLD;
		_count = count;
		_chunkEnumerator = default;
	}

	internal readonly World World { get; }

	[Inline]
	public readonly int Count => _count > 0 ?
		Math.Min(_count, _chunkEnumerator.CurrentRef.Count)
		:
		_chunkEnumerator.CurrentRef.Count;

	[Inline]
	public Span<uint64> Entities()
	{
		var span = _chunkEnumerator.Current.GetEntities();
		if (!span.IsEmpty)
			span = span.Slice(_startSafe, Count);
		return span;
	}

	[Inline]
	public Span<T> Data<T>(int index) where T : struct
	{
		var span = _chunkEnumerator.Current.GetSpan<T>(_indices[index]);
		if (!span.IsEmpty)
			span = span.Slice(_startSafe, Count);
		return span;
	}

	[Inline]
	public DataRow<T> GetColumn<T>(int index) where T : struct
	{
		DataRow<T> dr = ?;

		if (index < 0 || index >= _indices.Length)
		{
			dr.Value = null;
			dr.Amount = 0;

			return dr;
		}

		let i = _indices[[Unchecked]index];
		if (i < 0)
		{
			dr.Value = null;
			dr.Amount = 0;

			return dr;
		}


		if (_chunkEnumerator.CurrentRef.GetColumn(i) case .Ok(var column))
		{
			dr.Value = (T*)column.Data;
			dr.Value += _startSafe;
			dr.Amount = 1;
		}
		else
		{
			dr.Value = null;
			dr.Amount = 0;
		}

		return dr;
	}

	[Inline]
	public bool Next() mut
	{
		while (true)
		{
			while (_chunkEnumerator.MoveNext())
			{
				if (_chunkEnumerator.CurrentRef.Count > 0)
					return true;
			}

			while (true)
			{
				if (!_archetypeEnumerator.MoveNext())
					return false;

				if (_archetypeEnumerator.CurrentRef.Count <= 0)
					continue;

				break;
			}

			let arch = ref _archetypeEnumerator.CurrentRef;
			for (var i < _indices.Length)
				_indices[i] = arch.GetComponentIndex(_terms[i].Id());
			_chunkEnumerator = arch.Chunks.Slice(_start >> Archetype.CHUNK_LOG2).GetEnumerator();
		}
	}
}

public struct DataRow<T> where T : struct
{
	public T* Value;
	public int Amount;

	[Inline]
	public void Next() mut => Value += Amount;
}



public enum Terms
{
	With,
	Without,
	Optional
}

public enum ArchetypeSearchResult
{
	Continue,
	Found,
	Stop
}

public interface IQueryTerm
	//IOpComparable
{
	uint64 Id();
	Terms Term();

	ArchetypeSearchResult Match(Archetype archetype);
}

public struct WithTerm : IQueryTerm
{
	private readonly uint64 _id;
	public this(uint64 id) => _id = id;

	public uint64 Id() => _id;
	public Terms Term() => .With;

	public ArchetypeSearchResult Match(Archetype archetype)
	{
		return archetype.HasIndex(_id) ? .Found : .Continue;
	}
}

public struct WithoutTerm : IQueryTerm
{
	private readonly uint64 _id;
	public this(uint64 id) => _id = id;

	public uint64 Id() => _id;
	public Terms Term() => .Without;

	public ArchetypeSearchResult Match(Archetype archetype)
	{
		return archetype.HasIndex(_id) ? .Stop : .Continue;
	}
}

public struct OptionalTerm : IQueryTerm
{
	private readonly uint64 _id;
	public this(uint64 id) => _id = id;

	public uint64 Id() => _id;
	public Terms Term() => .Optional;

	public ArchetypeSearchResult Match(Archetype archetype)
	{
		return .Found;
	}
}

public static class FileterMatch
{
	public static ArchetypeSearchResult Match(Archetype archetype, Span<IQueryTerm> terms)
	{
		for (let term in ref terms)
		{
			let result = term.Match(archetype);

			if (result == .Stop || (term.Term() == .With && result == .Continue))
				return result;
		}

		return .Found;
	}
}