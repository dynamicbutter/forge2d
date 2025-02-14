import 'dart:math';

import '../../../forge2d.dart';
import '../../callbacks/contact_listener.dart';

/// The class manages contact between two shapes. A contact exists for each overlapping AABB in the
/// broad-phase (except if filtered). Therefore a contact object may exist that has no contact
/// points.
/// TODO.spydon: Add generics
abstract class Contact {
  // Flags stored in _flags
  // Used when crawling contact graph when forming islands.
  static const int islandFlag = 0x0001;
  // Set when the shapes are touching.
  static const int touchingFlag = 0x0002;
  // This contact can be disabled (by user)
  static const int enabledFlag = 0x0004;
  // This contact needs filtering because a fixture filter was changed.
  static const int filterFlag = 0x0008;
  // This bullet contact had a TOI event
  static const int bulletHitFlag = 0x0010;

  static const int toiFlag = 0x0020;

  int flags = 0;

  final Fixture fixtureA;
  final Fixture fixtureB;

  final int indexA;
  final int indexB;

  Body get bodyA => fixtureA.body;
  Body get bodyB => fixtureB.body;

  final ContactPositionConstraint positionConstraint =
      ContactPositionConstraint();
  final ContactVelocityConstraint velocityConstraint =
      ContactVelocityConstraint();

  final Manifold manifold = Manifold();

  int toiCount = 0;
  double toi = 0.0;

  double _friction = 0.0;
  double get friction => _friction;
  double _restitution = 0.0;
  double get restitution => _restitution;

  double tangentSpeed = 0.0;

  Contact(this.fixtureA, this.indexA, this.fixtureB, this.indexB) {
    flags = enabledFlag;
    manifold.pointCount = 0;
    _friction = Contact.mixFriction(
      fixtureA.friction,
      fixtureB.friction,
    );
    _restitution = Contact.mixRestitution(
      fixtureA.restitution,
      fixtureB.restitution,
    );
  }

  static Contact init(
    Fixture fixtureA,
    int indexA,
    Fixture fixtureB,
    int indexB,
  ) {
    // Remember that we use the order in the enum here to determine in which
    // order the arguments should come in the different contact classes.
    // { CIRCLE, EDGE, POLYGON, CHAIN }
    /// TODO.spydon: Clean this mess up.
    final typeA = fixtureA.type.index < fixtureB.type.index
        ? fixtureA.type
        : fixtureB.type;
    final typeB = fixtureA.type == typeA ? fixtureB.type : fixtureA.type;
    final indexTemp = indexA;
    final firstIndex = fixtureA.type == typeA ? indexA : indexB;
    final secondIndex = fixtureB.type == typeB ? indexB : indexTemp;
    final temp = fixtureA;
    final firstFixture = fixtureA.type == typeA ? fixtureA : fixtureB;
    final secondFixture = fixtureB.type == typeB ? fixtureB : temp;

    if (typeA == ShapeType.circle && typeB == ShapeType.circle) {
      return CircleContact(firstFixture, secondFixture);
    } else if (typeA == ShapeType.polygon && typeB == ShapeType.polygon) {
      return PolygonContact(firstFixture, secondFixture);
    } else if (typeA == ShapeType.circle && typeB == ShapeType.polygon) {
      return PolygonAndCircleContact(secondFixture, firstFixture);
    } else if (typeA == ShapeType.circle && typeB == ShapeType.edge) {
      return EdgeAndCircleContact(
        secondFixture,
        secondIndex,
        firstFixture,
        firstIndex,
      );
    } else if (typeA == ShapeType.edge && typeB == ShapeType.polygon) {
      return EdgeAndPolygonContact(
        firstFixture,
        firstIndex,
        secondFixture,
        secondIndex,
      );
    } else if (typeA == ShapeType.circle && typeB == ShapeType.chain) {
      return ChainAndCircleContact(
        secondFixture,
        secondIndex,
        firstFixture,
        firstIndex,
      );
    } else if (typeA == ShapeType.polygon && typeB == ShapeType.chain) {
      return ChainAndPolygonContact(
        secondFixture,
        secondIndex,
        firstFixture,
        firstIndex,
      );
    } else {
      assert(false, 'Not compatible contact type');
      return CircleContact(firstFixture, secondFixture);
    }
  }

  /// Get the world manifold.
  void getWorldManifold(WorldManifold worldManifold) {
    worldManifold.initialize(
      manifold,
      fixtureA.body.transform,
      fixtureA.shape.radius,
      fixtureB.body.transform,
      fixtureB.shape.radius,
    );
  }

  /// Whether the body is connected to the joint
  bool containsBody(Body body) => body == bodyA || body == bodyB;

  /// Get the other body than the argument in the contact
  Body getOtherBody(Body body) {
    assert(containsBody(body), 'Body is not in contact');
    return body == bodyA ? bodyB : bodyA;
  }

  /// Is this contact touching
  bool isTouching() => (flags & touchingFlag) == touchingFlag;

  bool representsArguments(
    Fixture fixtureA,
    int indexA,
    Fixture fixtureB,
    int indexB,
  ) {
    return (this.fixtureA == fixtureA &&
            this.indexA == indexA &&
            this.fixtureB == fixtureB &&
            this.indexB == indexB) ||
        (this.fixtureA == fixtureB &&
            this.indexA == indexB &&
            this.fixtureB == fixtureA &&
            this.indexB == indexA);
  }

  /// Enable/disable this contact. This can be used inside the pre-solve contact listener. The
  /// contact is only disabled for the current time step (or sub-step in continuous collisions).
  void setEnabled(bool enable) {
    if (enable) {
      flags |= enabledFlag;
    } else {
      flags &= ~enabledFlag;
    }
  }

  /// Has this contact been disabled?
  bool isEnabled() => (flags & enabledFlag) == enabledFlag;

  void resetFriction() {
    _friction = Contact.mixFriction(fixtureA.friction, fixtureB.friction);
  }

  void resetRestitution() {
    _restitution =
        Contact.mixRestitution(fixtureA.restitution, fixtureB.restitution);
  }

  void evaluate(Manifold manifold, Transform xfA, Transform xfB);

  /// Flag this contact for filtering. Filtering will occur the next time step.
  void flagForFiltering() {
    flags |= filterFlag;
  }

  // djm pooling
  final Manifold _oldManifold = Manifold();

  void update(ContactListener? listener) {
    _oldManifold.set(manifold);

    // Re-enable this contact.
    flags |= enabledFlag;

    var touching = false;
    final wasTouching = (flags & touchingFlag) == touchingFlag;

    final sensorA = fixtureA.isSensor;
    final sensorB = fixtureB.isSensor;
    final sensor = sensorA || sensorB;

    final bodyA = fixtureA.body;
    final bodyB = fixtureB.body;
    final xfA = bodyA.transform;
    final xfB = bodyB.transform;

    if (sensor) {
      final shapeA = fixtureA.shape;
      final shapeB = fixtureB.shape;
      touching = World.collision.testOverlap(
        shapeA,
        indexA,
        shapeB,
        indexB,
        xfA,
        xfB,
      );

      // Sensors don't generate manifolds.
      manifold.pointCount = 0;
    } else {
      evaluate(manifold, xfA, xfB);
      touching = manifold.pointCount > 0;

      // Match old contact ids to new contact ids and copy the
      // stored impulses to warm start the solver.
      for (var i = 0; i < manifold.pointCount; ++i) {
        final mp2 = manifold.points[i];
        mp2.normalImpulse = 0.0;
        mp2.tangentImpulse = 0.0;
        final id2 = mp2.id;

        for (var j = 0; j < _oldManifold.pointCount; ++j) {
          final mp1 = _oldManifold.points[j];

          if (mp1.id.isEqual(id2)) {
            mp2.normalImpulse = mp1.normalImpulse;
            mp2.tangentImpulse = mp1.tangentImpulse;
            break;
          }
        }
      }

      if (touching != wasTouching) {
        bodyA.setAwake(true);
        bodyB.setAwake(true);
      }
    }

    if (touching) {
      flags |= touchingFlag;
    } else {
      flags &= ~touchingFlag;
    }

    if (listener == null) {
      return;
    }

    if (wasTouching == false && touching == true) {
      listener.beginContact(this);
    }

    if (wasTouching == true && touching == false) {
      listener.endContact(this);
    }

    if (sensor == false && touching) {
      listener.preSolve(this, _oldManifold);
    }
  }

  /// Friction mixing law. The idea is to allow either fixture to drive the restitution to zero. For
  /// example, anything slides on ice.
  static double mixFriction(double friction1, double friction2) {
    return sqrt(friction1 * friction2);
  }

  /// Restitution mixing law. The idea is allow for anything to bounce off an inelastic surface. For
  /// example, a super ball bounces on anything.
  static double mixRestitution(double restitution1, double restitution2) {
    return restitution1 > restitution2 ? restitution1 : restitution2;
  }
}
