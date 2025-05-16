using System.Collections;
using System;
using tecs;

namespace tecs;

using internal tecs;

public class Scheduler
{
	private LinkedList<FuncSystem>[] _systems = new LinkedList<FuncSystem>[(.)Stages.OnExit + 1] ~ { for (let list in _) { ClearAndDeleteItems!(list); delete list; } delete _; }
	private readonly List<ISystemParam> _systemParamsCache = new .() ~ DeleteContainerAndItems!(_);

	public this(World world)
	{
		World = world;

		for (var i < _systems.Count)
			_systems[i] = new .();

		AddSystemParam(new Commands(World));
	}

	public World World { get; }


	public void AddResource<T>(T resource)
		=> AddSystemParam(new Res<T>() { Value = resource });

	public void AddSystemParam<T>(T param) where T : ISystemParam<Scheduler>, class
	{
		_systemParamsCache.Add(param);

		var ph = Placeholder<T>();
		ph.Value = param;
		World.Entity<Placeholder<T>>().Set(ph);
	}

	public bool ResourceExists<T>() where T : ISystemParam<Scheduler>
		=> World.Entity<Placeholder<T>>().Has<Placeholder<T>>();

	public T GetResource<T>() where T : ISystemParam<Scheduler>
		=> World.Entity<Placeholder<T>>().Get<Placeholder<T>>().Value;


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
		where T0 : ISystemParam<Scheduler>, IIntoSystemParam<Scheduler, T0>
	{
		delegate bool(SystemTicks, World, delegate bool()) dlg = new [=fn, =this] (ticks, world, conditions) =>
			{
				if (conditions?.Invoke() ?? true)
				{
					let t0 = T0.Generate(this);

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

public sealed class Commands : SystemParam<Scheduler>, IIntoSystemParam<Scheduler, Commands>
{
	private readonly World _world;

	internal this(World world) => _world = world;


	public static Commands Generate(Scheduler arg)
	{
		if (arg.ResourceExists<Commands>())
			return arg.GetResource<Commands>();

		Runtime.Assert(false);
		return default;
	}
}

public sealed class Res<T> : SystemParam<Scheduler>, IIntoSystemParam<Scheduler, Res<T>>
{
	private T _value;
	public ref T Value => ref _value;


	public static Res<T> Generate(Scheduler arg)
	{
		if (arg.ResourceExists<Res<T>>())
			return arg.GetResource<Res<T>>();

		var res = new Res<T>();
		res.Value = default;

		arg.AddSystemParam(res);

		return res;
	}
}

public sealed class Local<T> : SystemParam<Scheduler>, IIntoSystemParam<Scheduler, Local<T>>
{
	private T _value;
	public ref T Value => ref _value;


	public static Local<T> Generate(Scheduler arg)
	{
		var ph = Placeholder<Local<T>>();
		ph.Value = null;

		return ph.Value;
	}
}

public sealed class Query<D, F> : SystemParam<Scheduler>, IIntoSystemParam<Scheduler, Query<D, F>>
	where D : Tuple
	where F : struct
{
	private readonly Query _query ~ delete _;

	internal this(Query query) => _query = query;


	public Data<D> GetEnumerator() => Data<D>(_query.Iter());


	public static Query<D, F> Generate(Scheduler arg)
	{
		if (arg.ResourceExists<Query<D, F>>())
			return arg.GetResource<Query<D, F>>();

		let builder = scope QueryBuilder(arg.World);

		let x = DataGen<D>.Build(builder);
		let y = FilterGen<F>.Build(builder);

		var query = new Query<D, F>(builder.Build());

		arg.AddSystemParam(query);

		return query;
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