using System;
using System.Threading;
using System.Collections;

namespace tecs;

internal static class Lookup
{
	private static int _index = 0;
	private static readonly Dictionary<uint64, ComponentInfo> _components = new .() ~ { _.Clear(); delete _; }

	public static readonly ref ComponentInfo GetComponent(uint64 id)
	{
		return ref _components[id];
	}

	public static class Component<T> where T : struct
	{
		public static readonly uint64 Id = (.)Interlocked.Increment(ref _index);
		public static readonly int32 Size = sizeof(T);
		public static readonly String Name = typeof(T).GetName(.. new .()) ~ delete _;
		public static readonly ComponentInfo Value = .(Id, Size, Name);


		static this()
		{
			_components.Add(Value.Id, Value);
		}
	}
}