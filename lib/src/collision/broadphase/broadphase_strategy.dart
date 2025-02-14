import '../../../forge2d.dart';
import '../../../src/callbacks/debug_draw.dart';
import '../../../src/callbacks/tree_callback.dart';
import '../../../src/callbacks/tree_raycast_callback.dart';

abstract class BroadPhaseStrategy {
  /// Create a proxy. Provide a tight fitting AABB and a userData pointer.
  int createProxy(AABB aabb, Object? userData);

  /// Destroy a proxy
  void destroyProxy(int proxyId);

  /// Move a proxy with a swepted AABB. If the proxy has moved outside of its fattened AABB, then the
  /// proxy is removed from the tree and re-inserted. Otherwise the function returns immediately.
  /// @return true if the proxy was re-inserted.
  bool moveProxy(int proxyId, AABB aabb, Vector2 displacement);

  Object? getUserData(int proxyId);

  AABB getFatAABB(int proxyId);

  /// Query an AABB for overlapping proxies. The callback class is called for each proxy that
  /// overlaps the supplied AABB.
  void query(TreeCallback callback, AABB aabb);

  /// Ray-cast against the proxies in the tree. This relies on the callback to perform a exact
  /// ray-cast in the case were the proxy contains a shape. The callback also performs the any
  /// collision filtering. This has performance roughly equal to k * log(n), where k is the number of
  /// collisions and n is the number of proxies in the tree.
  ///
  /// @param input the ray-cast input data. The ray extends from p1 to p1 + maxFraction * (p2 - p1).
  /// @param callback a callback class that is called for each proxy that is hit by the ray.
  void raycast(TreeRayCastCallback callback, RayCastInput input);

  /// Compute the height of the tree.
  int computeHeight();

  /// Compute the height of the binary tree in O(N) time. Should not be called often.
  ///
  /// @return
  int getHeight();

  /// Get the maximum balance of an node in the tree. The balance is the difference in height of the
  /// two children of a node.
  int getMaxBalance();

  /// Get the ratio of the sum of the node areas to the root area.
  double getAreaRatio();

  void drawTree(DebugDraw draw);
}
