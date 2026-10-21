import 'package:flutter_test/flutter_test.dart';
import 'package:lexiflip/models/flashcard.dart';
import 'package:lexiflip/services/json_sync_service.dart';

void main() {
  test('card JSON round-trip keeps status and deck', () {
    final card = Flashcard.create(deckId: 'd1', word: 'kitob', primaryTranslation: 'book')
        .copyWith(status: CardStatus.problem, wrong: 2);
    final back = Flashcard.fromJson(card.toJson());
    expect(back.deckId, 'd1');
    expect(back.status, CardStatus.problem);
    expect(back.wrong, 2);
  });

  test('v1 single-deck file decodes into one deck without id', () {
    final decks = JsonSyncService.decode(
      '{"deck":"Test","cards":[{"word":"a"},{"word":"b"}]}',
    );
    expect(decks.length, 1);
    expect(decks.first.id, isNull);
    expect(decks.first.cards.length, 2);
  });
}
