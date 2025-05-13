namespace tecs;

internal static class EcsOp
{
	public static uint64 GetGeneration(uint64 id)
	{
		return ((id & EcsConst.ECS_GENERATION_MASK) >> 32);
	}

	public static uint64 IncreaseGeneration(uint64 id)
	{
		return ((id & ~EcsConst.ECS_GENERATION_MASK) | ((0xFFFF & (GetGeneration(id) + 1)) << 32));
	}

	public static uint64 RealID(uint64 id)
	{
		var id;
		return id &= EcsConst.ECS_ENTITY_MASK;
	}

	public static bool HasFlag(uint64 id, uint64 flag)
	{
		return (id & flag) != 0;
	}

	public static bool IsComponent(uint64 id)
	{
		return (id & ~EcsConst.ECS_COMPONENT_MASK) != 0;
	}
}