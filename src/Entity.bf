using System;
namespace tecs;

public struct Entity
{
	private readonly World _world;

	[Inline]
	internal this(World world, uint64 id)
	{
		_world = world;
		Id = id;
	}


	public uint64 Id { get; }


	[Inline]
	public ref Self Set<T>(T component) mut where T : struct
	{
		_world.Set<T>(Id, component);
		return ref this;
	}

	[Inline]
	public ref Self Add<T>() mut where T : struct
	{
		_world.Add<T>(Id);
		return ref this;
	}

	[Inline]
	public ref Self Unset<T>() mut where T : struct
	{
		_world.Unset<T>(Id);
		return ref this;
	}

	[Inline]
	public ref T Get<T>() where T : struct
		=> ref _world.Get<T>(Id);

	[Inline]
	public bool Has<T>() where T : struct
		=> _world.Has<T>(Id);

	[Inline]
	public void Delete()
		=> _world.Delete(Id);

	[Inline]
	public bool Exists()
		=> _world.Exists(Id);
}