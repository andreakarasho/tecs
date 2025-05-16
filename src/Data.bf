using System;
using System.Collections;
using System.Reflection;
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
		for (let field in type.GetFields(.Instance | .Public))
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

internal struct DataGen<TArgs>
	where TArgs : Tuple
{
	[OnCompile(.TypeInit), Comptime]
	public static void Generate()
	{
		let type = typeof(TArgs);

		var m = scope String("public static void Build(QueryBuilder builder) {\n");

		for (let field in type.GetFields(.Instance | .Public))
		{
			if (field.FieldType == typeof(Entity))
				continue;

			m..Append(scope $"builder.With<{field.FieldType.UnderlyingType}>();\n");
		}

		m.Append("}");

		Compiler.EmitTypeBody(typeof(Self), m);
	}
}

internal struct FilterGen<TArgs>
	where TArgs : struct
{
	[OnCompile(.TypeInit), Comptime]
	public static void Generate()
	{
		let type = typeof(TArgs);

		var m = scope String("public static void Build(QueryBuilder builder) {\n");

		if (type.IsTuple)
		{
			for (let field in type.GetFields(.Instance | .Public))
			{
				AppendType(field.FieldType, m);
			}
		}
		else
		{
			AppendType(type, m);
		}

		m.Append("}");

		Compiler.EmitTypeBody(typeof(Self), m);
	}

	[Comptime]
	private static void AppendType(Type type, String m)
	{
		if (var gen = type as SpecializedGenericType)
		{
			if (gen.UnspecializedType == typeof(With<>))
			{
				m..Append("builder.With<");
			}
			else if (gen.UnspecializedType == typeof(Without<>))
			{
				m..Append("builder.Without<");
			}
			else if (gen.UnspecializedType == typeof(Optional<>))
			{
				m..Append("builder.Optional<");
			}
			else
			{
				Runtime.Assert(false);
			}

			Runtime.Assert(gen.GenericParamCount == 1);
			let first = gen.GetGenericArg(0);
			m..Append(scope $"{first}>();\n");
		}
	}
}