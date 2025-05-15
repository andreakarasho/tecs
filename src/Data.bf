using System;
using System.Collections;
namespace tecs;

public struct Data<TArgs> : IRefEnumerator<TArgs>
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
		var index = 0;
		for (let field in type.GetFields())
		{
			if (field.FieldType == typeof(Entity))
			{
				Compiler.EmitTypeBody(typeof(Self), "private Span<uint64> _entities = .();\n");

				f..Append("_entities = _it.Entities();\n");
				r..Append(".(_it.World, _entities[_index])");
			}
			else
			{
				Compiler.EmitTypeBody(typeof(Self), scope $"""
					private DataRow<{field.FieldType.UnderlyingType}> _{field.Name} = default;\n
					""");

				f..Append(scope $"_{field.Name} = _it.GetColumn<{field.FieldType.UnderlyingType}>({index++});\n");
				n..Append(scope $"_{field.Name}.Next();\n");
				r..Append(scope $"_{field.Name}.Value");
			}

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
			[Inline]
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

	public Data<TArgs> GetEnumerator() => this;
}