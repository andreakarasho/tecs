using System;
using System.Threading;

namespace tecs;

public static class Lookup
{
	private static int _index = 0;


	public static class Component<T> where T : struct
	{
		public static readonly uint64 Id = (.)Interlocked.Increment(ref _index);
		public static readonly int Size = sizeof(T);
		public static readonly String Name = GetName() ~ delete _;
		public static readonly ComponentInfo Value = .(Id, Size);


		private static String GetName()
		{
			var str = new String();
			typeof(T).GetName(str);
			return str;
		}
	}
}