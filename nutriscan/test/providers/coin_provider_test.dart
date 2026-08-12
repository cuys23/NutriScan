import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<CoinProvider> freshProvider() async {
  final provider = CoinProvider();
  // The constructor's initial load is fire-and-forget; reloadCoins() re-runs
  // it and awaits, giving a deterministic settled state for the test.
  await provider.reloadCoins();
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CoinProvider money path', () {
    test('grants initialCoins on first load', () async {
      final provider = await freshProvider();
      expect(provider.coinBalance, CoinProvider.initialCoins);
    });

    test('spendCoins succeeds and decrements balance when affordable', () async {
      final provider = await freshProvider();
      final spent = await provider.spendCoins(CoinProvider.coinsPerScan);
      expect(spent, isTrue);
      expect(
        provider.coinBalance,
        CoinProvider.initialCoins - CoinProvider.coinsPerScan,
      );
    });

    test(
      'spendCoins fails and leaves balance untouched when insufficient',
      () async {
        final provider = await freshProvider();
        final spent = await provider.spendCoins(provider.coinBalance + 1);
        expect(spent, isFalse);
        expect(provider.coinBalance, CoinProvider.initialCoins);
      },
    );

    test(
      'refundCoins undoes a spend without inflating totalCoinsEarned',
      () async {
        final provider = await freshProvider();
        final earnedBefore = provider.totalCoinsEarned;
        await provider.spendCoins(CoinProvider.coinsPerScan);
        await provider.refundCoins(CoinProvider.coinsPerScan);
        expect(provider.coinBalance, CoinProvider.initialCoins);
        expect(provider.totalCoinsEarned, earnedBefore);
      },
    );

    test('canScan reflects whether balance still covers one scan', () async {
      final provider = await freshProvider();
      expect(provider.canScan(), isTrue);
      while (provider.canScan()) {
        await provider.spendCoins(CoinProvider.coinsPerScan);
      }
      expect(provider.canScan(), isFalse);
      // A zero/low balance must never let spendCoins succeed anyway — this
      // is the actual gate analyzeFoodImage relies on, not just canScan().
      expect(await provider.spendCoins(CoinProvider.coinsPerScan), isFalse);
    });
  });
}
