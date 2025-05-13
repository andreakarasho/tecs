using System;
namespace tecs;

static class NiceHash
{
	private const uint64 PRIME = 0x9E3779B185EBCA87UL;

	public static uint64 Combine(Span<uint64> values)
	{
		uint64 hash = 0;

		for (let value in ref values)
		{
			hash ^= Mix(value);
			hash *= PRIME;
		}

		return hash;
	}

	public static uint64 Combine(uint64 currentHash, uint64 mixed)
	{
		return (currentHash ^ mixed) * PRIME;
	}

	private static uint64 Mix(uint64 x)
	{
		var x;
		// A simple mixer (variant of MurmurHash3 finalizer)
		x ^= x >> 30;
		x *= 0xbf58476d1ce4e5b9UL;
		x ^= x >> 27;
		x *= 0x94d049bb133111ebUL;
		x ^= x >> 31;
		return x;
	}
}