namespace tecs;

internal static class EcsConst
{
	public const uint64 ECS_ENTITY_MASK = 0xFFFFFFFFu;
	public const uint64 ECS_GENERATION_MASK = (0xFFFFu << 32);
	public const uint64 ECS_ID_FLAGS_MASK = (0xFFu << 60);
	public const uint64 ECS_COMPONENT_MASK = ~ECS_ID_FLAGS_MASK;
}