using System;
using System.Collections;
using System.Diagnostics;
using tecs;

namespace tecs;

static class Program
{
	public static void Main(String[] args)
	{
		const int TOTAL_ENTITIES = 524288 * 2 * 1;

		var world = scope World();
		/*let e0 = world.Entity();
		let e1 = world.Entity();
		let e2 = world.Entity();

		world.Delete(e1);
		let e3 = world.Entity();
		world.Set(e3, Position() { X = 1, Y = 33 });
		world.Set(e3, Velocity() { X = -12, Y = 999 });
		world.Add<Tag>(e3);

		//world.Delete(e3);

		var p = ref world.Get<Position>(e3);
		var v = ref world.Get<Velocity>(e3);
		var vv = ref world.Get<Tag>(e3);*/

		for (var i < TOTAL_ENTITIES)
		{
			let ee = world.Entity();
			world.Set(ee, Position() { X = i + 1 });
			world.Set(ee, Velocity() { X = i + 1 });
		}

		let posId = world.Component<Position>().Id;
		let velId = world.Component<Velocity>().Id;
		let query = scope Query(world, WithTerm(posId), WithTerm(velId));


		int64 start = 0;
		int64 last = 0;

		Stopwatch sw = scope .();
		sw.Start();

		while (true)
		{
			for (var i < 3600)
			{
				var iter = query.Iter();
				var data = Data2<(Position*, Velocity*)>(iter);

				for (var (pos, vel) in ref data)
				{
					pos.X *= vel.X;
					pos.Y *= vel.Y;
				}

				/*while (iter.Next())
				{
					let count = iter.Count;

					/*var span0 = iter.Data<Position>(0);
					var span1 = iter.Data<Velocity>(1);

					for (var j < count)
					{
						var p0 = ref span0[[Unchecked]j];
						var p1 = ref span1[[Unchecked]j];

						p0.X *= p1.X;
						p0.Y *= p1.Y;
					}*/

					var p0 = iter.GetColumn<Position>(0);
					var v0 = iter.GetColumn<Velocity>(1);

					for (var j < count)
					{
						p0.Value.X *= v0.Value.X;
						p0.Value.Y *= v0.Value.Y;

						p0.Next();
						v0.Next();
					}
				}*/
			}

			last = start;
			start = sw.ElapsedMilliseconds;

			Console.WriteLine(scope $"query done in {(start - last)} ms");
		}
	}
}

/*struct Data2<TArgs> where TArgs : Tuple
{
	public this()
	{
		Args = default;
		TArgs.T();
	}

	public void X(params TArgs a)
	{
	}

	public TArgs Args { get mut; }
}*/

/*struct Data<T0, T1> : IRefEnumerator<(T0*, T1*)>
	where T0 : struct
	where T1 : struct
{
	private QueryIterator _it;
	private DataRow<T0*> _arr0;
	private DataRow<T1*> _arr1;
	private Span<uint64> _entities;
	private int _index, _count;


	public this(QueryIterator it)
	{
		_it = it;
		_arr0 = default;
		_arr1 = default;
		_index = -1;
		_count = -1;
		_entities = .();
	}

	/*public ref (T0*, T1*) CurrentRef
	{
		[Inline]
		get mut
		{
			return ref (_arr0.Value, _arr1.Value);
		}
	}*/

	[Inline]
	public Result<(T0*, T1*)> GetNextRef() mut
	{
		if (++_index >= _count)
		{
			if (!_it.Next())
				return .Err;

			_arr0 = _it.GetColumn<T0*>(0);
			_arr1 = _it.GetColumn<T1*>(1);
			_entities = _it.Entities();

			_index = 0;
			_count = _it.Count;
		}
		else
		{
			_arr0.Next();
			_arr1.Next();
		}

		return .Ok((_arr0.Value, _arr1.Value));
	}

	[Inline]
	public Data<T0, T1> GetEnumerator() => this;
}*/

struct Position { public float X, Y, Z; }
struct Velocity { public float X, Y; }
struct Mass { public int32 Value; }
struct Tag { }


public struct Data2<TArgs> : IRefEnumerator<TArgs>
	where TArgs : Tuple
{
	private QueryIterator _it;
	private int _index, _count;

	public this(QueryIterator it)
	{
		_it = it;
		_index = -1;
		_count = -1;
	}

	[OnCompile(.TypeInit), Comptime]
	public static void Generate()
	{
		let type = typeof(TArgs);

		var f = scope String();
		var n = scope String();
		var r = scope String("(");

		var i = 0;
		for (let field in type.GetFields())
		{
			Compiler.EmitTypeBody(typeof(Self), scope $"""
				private DataRow<{field.FieldType.UnderlyingType}> _{field.Name} = default;\n
				""");

			f..Append(scope $"_{field.Name} = _it.GetColumn<{field.FieldType.UnderlyingType}>({field.FieldIdx});\n");
			n..Append(scope $"_{field.Name}.Next();\n");
			r..Append(scope $"_{field.Name}.Value");

			if (i < type.FieldCount - 1)
			{
				r..Append(", ");
			}

			i += 1;
		}

		r..Append(")");

		if (type.FieldCount == 0)
		{
			r.Set("default");
		}

		Compiler.EmitTypeBody(typeof(Self), scope $"""
			public Result<TArgs> GetNextRef() mut
			{{
				if (++_index >= _count)
				{{
					if (!_it.Next())
						return .Err;
	
					{f}
					_index = 0;
					_count = _it.Count;
				}}
				else
				{{
					{n}
				}}
	
				return .Ok({r});
			}}

			""");
	}

	public Data2<TArgs> GetEnumerator() => this;
}