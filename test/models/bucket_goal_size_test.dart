import 'package:flutter_test/flutter_test.dart';
import 'package:nori/models/bucket_list_item.dart';

void main() {
  test('the biggest size is what the server will pay', () {
    expect(BucketGoalSize.big.xp, BucketListItem.maxXpReward);
    expect(BucketGoalSize.big.coins, BucketListItem.maxCoinReward);
  });

  test('goals saved before sizes existed map to the closest size', () {
    expect(BucketGoalSize.nearest(10), BucketGoalSize.small);
    expect(BucketGoalSize.nearest(50), BucketGoalSize.medium);
    expect(BucketGoalSize.nearest(75), BucketGoalSize.medium);
    expect(BucketGoalSize.nearest(250), BucketGoalSize.big);
    expect(BucketGoalSize.nearest(0), BucketGoalSize.small);
  });
}
