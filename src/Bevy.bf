using System.Collections;
using System;
using tecs;

namespace tecs;

using internal tecs;

public class Scheduler
{
	private LinkedList<FuncSystem>[] _systems = new LinkedList<FuncSystem>[(.)Stages.OnExit + 1] ~ { for (let list in _) { ClearAndDeleteItems!(list); delete list; } delete _; }
	private readonly Commands _commands ~ delete _commands;

	public this(World world)
	{
		World = world;

		for (var i < _systems.Count)
			_systems[i] = new .();

		_commands = new .(World);
		AddSystemParam(_commands);
	}

	public World World { get; }


	public void AddResource<T>(T resource)
		=> AddSystemParam(new Res<T>() { Value = resource });

	public void AddSystemParam<T>(T param) where T : ISystemParam<World>
	{
		var ph = Placeholder<T>();
		ph.Value = param;
		World.Entity<Placeholder<T>>().Set(ph);
	}

	public bool ResourceExists<T>() where T : ISystemParam<World>
		=> World.Entity<Placeholder<T>>().Has<Placeholder<T>>();


	public void RunOnce()
	{
		let ticks = 0u; //World.Update();

		RunStage(.Startup, ticks);
		//_systems[(.)Stages.Startup].Clear();

		RunStage(.OnExit, ticks);
		RunStage(.OnEnter, ticks);

		for (var stage = Stages.FrameStart; stage <= .FrameEnd; stage += 1)
		{
			RunStage(stage, ticks);
		}
	}

	private void RunStage(Stages stage, uint32 ticks)
	{
		let systems = _systems[(.)stage];

		for (let sys in systems)
		{
			sys.Run(ticks);
		}
	}


	/*public FuncSystem OnUpdate(function void() fn)
	{
		delegate bool(SystemTicks ticks, World world, delegate bool() conditions) dlg = new (ticks, world, conditions) =>
			{
				if (conditions?.Invoke() ?? true)
				{
					fn();
					return true;
				}

				return false;
			};

		var system = new FuncSystem(World, (.)dlg);

		_systems[(.)Stages.Update].AddLast(system);

		return system;
	}*/

	public FuncSystem OnUpdate<T0>(function void(T0) fn)
		where T0 : ISystemParam<World>, IIntoSystemParam<World, T0>
	{
		delegate bool(SystemTicks, World, delegate bool()) dlg = new [=fn] (ticks, world, conditions) =>
			{
				if (conditions?.Invoke() ?? true)
				{
					let t0 = T0.Generate(world);

					t0.Lock(ticks);
					fn(t0);
					t0.Unlock();
					return true;
				}

				return false;
			};

		var system = new FuncSystem(World, dlg);

		_systems[(.)Stages.Update].AddLast(system);

		return system;
	}
}

public interface ISystemParam
{
	void Lock(SystemTicks ticks);
	void Unlock();
}

public interface ISystemParam<T> : ISystemParam
{
}

public interface IIntoSystemParam<T, TOut> where TOut : ISystemParam<T>
{
	public static TOut Generate(T arg);
}

public abstract class SystemParam<T> : ISystemParam<T>
{
	public SystemTicks Ticks { get; } = new .() ~ delete _;

	public void Lock(SystemTicks ticks)
	{
		Ticks.ThisRun = ticks.ThisRun;
		Ticks.LastRun = ticks.LastRun;
	}

	public void Unlock()
	{
		Ticks.LastRun = Ticks.ThisRun;
	}
}

public sealed class FuncSystem
{
	typealias ValidatorFn = delegate bool(SystemTicks ticks, World world);
	typealias SystemFn = delegate bool(SystemTicks ticks, World world, delegate bool() validator);

	private readonly delegate bool() _validator = new => ValidateConditions ~ delete _;
	private readonly List<ValidatorFn> _conditions = new .() ~ { _.Clear(); delete _; }
	private readonly SystemFn _system;
	private readonly World _world;


	internal this(World world, SystemFn system)
	{
		_world = world;
		_system = system;
	}


	public SystemTicks Ticks { get; } = new .() ~ delete _;


	public void Run(uint32 ticks)
	{
		Ticks.ThisRun = ticks;

		if (_system(Ticks, _world, _validator))
		{
		}

		Ticks.LastRun = Ticks.ThisRun;
	}

	private bool ValidateConditions()
	{
		for (let c in _conditions)
			if (!c(Ticks, _world))
				return false;
		return true;
	}
}

public sealed class SystemTicks
{
	public uint32 LastRun { get; set; }
	public uint32 ThisRun { get; set; }
}

public enum Stages
{
	Startup,
	FrameStart,
	BeforeUpdate,
	Update,
	AfterUpdate,
	FrameEnd,

	OnEnter,
	OnExit
}

public sealed class Commands : SystemParam<World>, IIntoSystemParam<World, Commands>
{
	private readonly World _world;

	internal this(World world) => _world = world;


	public static Commands Generate(World arg)
	{
		if (arg.Entity<Placeholder<Commands>>().Has<Placeholder<Commands>>())
			return arg.Entity<Placeholder<Commands>>().Get<Placeholder<Commands>>().Value;

		var ph = Placeholder<Commands>();
		ph.Value = new Commands(arg);

		arg.Entity<Placeholder<Commands>>().Set(ph);

		return ph.Value;
	}
}

public sealed class Res<T> : SystemParam<World>, IIntoSystemParam<World, Res<T>>
{
	private T _value;
	public ref T Value => ref _value;


	public static Res<T> Generate(World arg)
	{
		if (arg.Entity<Placeholder<Res<T>>>().Has<Placeholder<Res<T>>>())
			return arg.Entity<Placeholder<Res<T>>>().Get<Placeholder<Res<T>>>().Value;

		var ph = Placeholder<Res<T>>();
		ph.Value = null;

		arg.Entity<Placeholder<Res<T>>>().Set(ph);

		return ph.Value;
	}
}

public sealed class Local<T> : SystemParam<World>, IIntoSystemParam<World, Local<T>>
{
	private T _value;
	public ref T Value => ref _value;


	public static Local<T> Generate(World arg)
	{
		var ph = Placeholder<Local<T>>();
		ph.Value = null;

		return ph.Value;
	}
}

public sealed class Query<D, F> : SystemParam<World>, IIntoSystemParam<World, Query<D, F>>
	where D : Tuple
	where F : struct
{
	private readonly Query _query ~ delete _;

	internal this(Query query) => _query = query;


	public Data<D> GetEnumerator() => Data<D>(_query.Iter());


	public static Query<D, F> Generate(World arg)
	{
		if (arg.Entity<Placeholder<Query<D, F>>>().Has<Placeholder<Query<D, F>>>())
			return arg.Entity<Placeholder<Query<D, F>>>().Get<Placeholder<Query<D, F>>>().Value;

		let builder = scope QueryBuilder(arg);

		let x = DataGen<D>.Build(builder);
		let y = FilterGen<F>.Build(builder);

		var ph = Placeholder<Query<D, F>>();
		ph.Value = new .(builder.Build());

		arg.Entity<Placeholder<Query<D, F>>>().Set(ph);

		return ph.Value;
	}
}

/*namespace System
{
	using internal tecs;

	extension Tuple : IFilter
	{
		//const List<Type> _fields = GetTupleFieldType(typeof(Self));

		public static void Build(QueryBuilder builder)
		{
		}


		/*[OnCompile(.TypeInit), Comptime]
		public static void Generate()
		{
			let type = typeof(Self);
			for (let field in type.GetFields())
			{
			}
		}*/

		/*[Comptime]
		private static List<Type> GetTupleFieldType(Type type)
		{
			//Runtime.Assert(type.IsTuple);

			List<Type> fields = new .();
			for (let field in type.GetFields())
			{
				fields.Add(field.FieldType);
			}

			return fields;
		}*/
	}
}*/


public struct Placeholder<T>
{
	public T Value;
}

public interface IFilter
{
	static void Build(QueryBuilder builder);
}

public struct With<T> : IFilter
	where T : struct
{
	public static void Build(QueryBuilder builder)
	{
		builder.With<T>();
	}
}

public struct Without<T> : IFilter
	where T : struct
{
	public static void Build(QueryBuilder builder)
	{
		builder.Without<T>();
	}
}

public struct Optional<T> : IFilter
	where T : struct
{
	public static void Build(QueryBuilder builder)
	{
		builder.Optional<T>();
	}
}