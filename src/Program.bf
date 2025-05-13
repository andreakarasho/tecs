using System;
using System.Collections;

namespace tecs;

static class Program
{
	public static void Main(String[] args)
	{
		/*var set = scope SparseSet<uint64>();


		while (true)
		{
			switch (set.CreateNew(let id))
			{
				case .Ok(let val):
					break;
				case .Err:
					break;
			}
		}*/

		var world = scope World();
		let e0 = world.Entity();
		let e1 = world.Entity();
		let e2 = world.Entity();

		world.Delete(e1);
		let e3 = world.Entity();


		let count = 4096;
		var arr0 = scope Position[count];
		var arr1 = scope Velocity[count];

		(var a, var b) = (1, 2);

		var en = PositionEnumerator<Position, Velocity>(arr0, arr1);

		for (var (pos, vel) in ref en)
		{
			pos.X += 1;
			vel.Y -= 1;
		}

		var query = scope Query<(Position, Velocity), void>();
	}

	static String F()
	{
		var s = scope String();
		return s;
	}

	static uint64 expensinve_calculation(int32 n)
	{
		uint64 sum = 0;
		for (int32 i = 0; i < n; ++i)
			sum += (uint64)(i * i);
		return sum;
	}
}


class Query<TData, TFilter>
	where TData : struct, ValueType
	where TFilter : struct
{
	public this()
	{
		TData.Do();
	}
}

public interface IValue
{
	public static void Do();
}

namespace System
{
	extension ValueType : tecs.IValue
	{
		public static void Do()
		{
		}
	}
}


public struct Data<T0, T1> where T0 : struct where T1 : struct
{
}

struct PositionEnumerator<T0, T1> : IRefEnumerator<(T0*, T1*)>
{
	private T0[] _arr0;
	private T1[] _arr1;
	private int _index, _count;
	private (T0*, T1*) _current;

	public this(T0[] arr0, T1[] arr1)
	{
		_arr0 = arr0;
		_arr1 = arr1;
		_index = -1;
		_count = arr0.Count;
		_current = default;
	}

	public ref (T0*, T1*) CurrentRef
	{
		[Inline]
		get mut
		{
			return ref _current;
		}
	}

	[Inline]
	public Result<(T0*, T1*)> GetNextRef() mut
	{
		if (!MoveNext())
			return .Err;
		return _current;
	}

	[Inline]
	public bool MoveNext() mut
	{
		if (++_index >= _count)
		{
			return false;
		}

		_current.0 = &_arr0[[Unchecked]_index];
		_current.1 = &_arr1[[Unchecked]_index];

		return true;
	}

	public PositionEnumerator<T0, T1> GetEnumerator() => this;
}

struct Position { public int32 X, Y; }
struct Velocity { public int32 X, Y; }
struct Tag { }

struct ArraySt
{
	public Array Data;
}