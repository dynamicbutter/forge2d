import '../../forge2d.dart';
import '../particle/particle.dart';

/// Implement this abstract class to allow DBox2d to automatically draw your physics for debugging
/// purposes. Not intended to replace your own custom rendering routines!
abstract class DebugDraw {
  /// Draw shapes
  static const int shapeBit = 1 << 1;

  /// Draw joint connections
  static const int jointBit = 1 << 2;

  /// Draw axis aligned bounding boxes
  static const int aabbBit = 1 << 3;

  /// Draw pairs of connected objects
  static const int pairBit = 1 << 4;

  /// Draw center of mass frame
  static const int centerOfMassBit = 1 << 5;

  /// Draw dynamic tree
  static const int dynamicTreeBit = 1 << 6;

  /// Draw only the wireframe for drawing performance
  static const int wireFrameDrawingBit = 1 << 7;

  int drawFlags = shapeBit;
  final ViewportTransform viewport;

  DebugDraw(this.viewport);

  void appendFlags(int flags) {
    drawFlags |= flags;
  }

  void clearFlags(int flags) {
    drawFlags &= ~flags;
  }

  /// Draw a closed polygon provided in CCW order. This implementation uses
  /// {@link #drawSegment(Vec2, Vec2, Color3f)} to draw each side of the polygon.
  void drawPolygon(List<Vector2> vertices, Color3i color) {
    final vertexCount = vertices.length;
    if (vertexCount == 1) {
      drawSegment(vertices[0], vertices[0], color);
      return;
    }

    for (var i = 0; i < vertexCount - 1; i += 1) {
      drawSegment(vertices[i], vertices[i + 1], color);
    }

    if (vertexCount > 2) {
      drawSegment(vertices[vertexCount - 1], vertices[0], color);
    }
  }

  void drawPoint(Vector2 argPoint, double argRadiusOnScreen, Color3i argColor);

  /// Draw a solid closed polygon provided in CCW order.
  void drawSolidPolygon(List<Vector2> vertices, Color3i color);

  /// Draw a circle.
  void drawCircle(Vector2 center, double radius, Color3i color);

  /// Draws a circle with an axis
  void drawCircleAxis(
    Vector2 center,
    double radius,
    Vector2 axis,
    Color3i color,
  ) {
    drawCircle(center, radius, color);
  }

  /// Draw a solid circle.
  void drawSolidCircle(Vector2 center, double radius, Color3i color);

  /// Draw a line segment.
  void drawSegment(Vector2 p1, Vector2 p2, Color3i color);

  /// Draw a transform. Choose your own length scale
  void drawTransform(Transform xf, Color3i color);

  /// Draw a string.
  void drawStringXY(double x, double y, String s, Color3i color);

  /// Draw a particle array
  void drawParticles(List<Particle> particles, double radius);

  /// Draw a particle array
  void drawParticlesWireframe(List<Particle> particles, double radius);

  /// Called at the end of drawing a world
  void flush() {}

  void drawString(Vector2 pos, String s, Color3i color) {
    drawStringXY(pos.x, pos.y, s, color);
  }

  /// Takes the world coordinate and returns the screen coordinates.
  Vector2 getWorldToScreen(Vector2 argWorld) =>
      viewport.worldToScreen(argWorld);

  /// Takes the world coordinates and returns the screen coordinates
  Vector2 getWorldToScreenXY(double worldX, double worldY) =>
      viewport.worldToScreen(Vector2(worldX, worldY));

  /// Takes the screen coordinates (argScreen) and returns the world coordinates
  Vector2 getScreenToWorld(Vector2 argScreen) =>
      viewport.screenToWorld(argScreen);
}
