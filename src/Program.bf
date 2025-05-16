using System;
using System.Collections;
using System.Diagnostics;
using tecs;
using System.Reflection;

namespace tecs;

static class Program
{
	public static void Main(String[] args)
	{
		const int TOTAL_ENTITIES = 524288 * 2 * 1;


		var world = scope World();
		var scheduler = scope Scheduler(world);


		/*let e0 = world.Entity();
		let e1 = world.Entity();
		let e2 = world.Entity();

		world.Delete(e1);
		let e3 = world.Entity();
		world.Set(e3, Position() { X = 1, Y = 33 });
		world.Set(e3, Velocity() { X = -12, Y = 999 });
		world.Add<Tag>(e3);

		//world.Delete(e3);

		var p = ref world.Get<Position>(e3);
		var v = ref world.Get<Velocity>(e3);
		var vv = ref world.Get<Tag>(e3);*/

		for (var i < TOTAL_ENTITIES)
		{
			var ee = world.Entity();
			ee.Set(Position() { X = i + 1 });
			ee.Set(Velocity() { Y = i + 1 });
		}

		var q = Query<(Position*, Velocity*), (With<Position>, With<Velocity>)>.Generate(world);
		var q2 = Query<(Entity, Position*, Velocity*), With<Position>>.Generate(world);

		for (var (pos, vel) in ref q)
		{
		}

		let posId = world.Component<Position>().Id;
		let velId = world.Component<Velocity>().Id;
		let query = scope Query(world, scope WithTerm(posId), scope WithTerm(velId));


		int64 start = 0;
		int64 last = 0;

		Stopwatch sw = scope .();
		sw.Start();

		while (true)
		{
			for (var i < 3600)
			{
				var iter = query.Iter();
				var data = Data<(Entity, Position*, Velocity*)>(iter);

				for (var (ent, pos, vel) in ref data)
				{
					pos.X *= vel.X;
					pos.Y *= vel.Y;
				}

				/*while (iter.Next())
				{
					let count = iter.Count;

					/*var span0 = iter.Data<Position>(0);
					var span1 = iter.Data<Velocity>(1);

					for (var j < count)
					{
						var p0 = ref span0[[Unchecked]j];
						var p1 = ref span1[[Unchecked]j];

						p0.X *= p1.X;
						p0.Y *= p1.Y;
					}*/

					var p0 = iter.GetColumn<Position>(0);
					var v0 = iter.GetColumn<Velocity>(1);

					for (var j < count)
					{
						p0.Value.X *= v0.Value.X;
						p0.Value.Y *= v0.Value.Y;

						p0.Next();
						v0.Next();
					}
				}*/
			}

			last = start;
			start = sw.ElapsedMilliseconds;

			Console.WriteLine(scope $"query done in {(start - last)} ms");
		}
	}
}


struct Position { public float X, Y, Z; }
struct Velocity { public float X, Y; }
struct Mass { public int32 Value; }
struct Tag { }
