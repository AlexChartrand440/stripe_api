import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stripe_text_utils.dart';
import 'card_utils.dart';
import 'model/card.dart';

final Set<int> SPACE_SET_COMMON = new Set()..add(4)..add(9)..add(14);
final Set<int> SPACE_SET_AMEX = Set()..add(4)..add(11);

class CardNumberTextField extends InheritedWidget {
  final ValueChanged<String> onCardBrandChanged;
  final VoidCallback onCardNumberComplete;

  CardNumberTextField({
    Key key,
    @required TextField child,
    this.onCardBrandChanged,
    this.onCardNumberComplete,
  }) : super(key: key, child: child) {
    child.inputFormatters.add(
      new _CardNumberFormatter(
        onCardBrandChanged,
        onCardNumberComplete,
      ),
    );
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  final ValueChanged<String> onCardBrandChanged;
  final VoidCallback onCardNumberComplete;

  String _cardBrand;
  int _lengthMax = 19;

  _CardNumberFormatter(this.onCardBrandChanged, this.onCardNumberComplete) {
    _cardBrand = StripeCard.UNKNOWN;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    //if()
    if (newValue.composing.isValid && newValue.composing.start < 4) {
      _updateCardBrandFromNumber(newValue.text);
    }

    String spacelessNumber = removeSpacesAndHyphens(newValue.text);
    if (spacelessNumber == null) {
      //return newValue.copyWith(text: );
      return newValue;
    }

    List<String> cardParts =
        separateCardNumberGroups(spacelessNumber, _cardBrand);
    String formattedNumber = '';
    for (int i = 0; i < cardParts.length; i++) {
      if (cardParts[i] == null) {
        break;
      }

      if (i != 0) {
        formattedNumber += ' ';
      }

      formattedNumber += cardParts[i];
    }

    /*
    int cursorPosition = _updateSelectionIndex(formattedNumber.length,
        oldValue.composing.start, newValue.composing.end);
        */

    return null;
  }

  void _updateCardBrand(String brand) {
    if (_cardBrand == brand) {
      return;
    }

    _cardBrand = brand;

    if (onCardBrandChanged != null) {
      onCardBrandChanged(brand);
    }

    int oldLength = _lengthMax;
    _lengthMax = getLengthForBrand(brand);
    if (oldLength == _lengthMax) {
      return;
    }

    //updateLengthFilter(); TODO:://
  }

  void _updateCardBrandFromNumber(String partialNumber) {
    _updateCardBrand(getPossibleCardType(partialNumber));
  }

  /**
   * Updates the selection index based on the current (pre-edit) index, and
   * the size change of the number being input.
   *
   * @param newLength the post-edit length of the string
   * @param editActionStart the position in the string at which the edit action starts
   * @param editActionAddition the number of new characters going into the string (zero for
   *                           delete)
   * @return an index within the string at which to put the cursor
   */
  int _updateSelectionIndex(
      int newLength, int editActionStart, int editActionAddition) {
    int newPosition, gapsJumped = 0;
    Set<int> gapSet = StripeCard.AMERICAN_EXPRESS == _cardBrand
        ? SPACE_SET_AMEX
        : SPACE_SET_COMMON;
    bool skipBack = false;
    for (int gap in gapSet) {
      if (editActionStart <= gap &&
          editActionStart + editActionAddition > gap) {
        gapsJumped++;
      }

      // editActionAddition can only be 0 if we are deleting,
      // so we need to check whether or not to skip backwards one space
      if (editActionAddition == 0 && editActionStart == gap + 1) {
        skipBack = true;
      }
    }

    newPosition = editActionStart + editActionAddition + gapsJumped;
    if (skipBack && newPosition > 0) {
      newPosition--;
    }

    return newPosition <= newLength ? newPosition : newLength;
  }
}

/**
 * Separates a card number according to the brand requirements, including prefixes of card
 * numbers, so that the groups can be easily displayed if the user is typing them in.
 * Note that this does not verify that the card number is valid, or even that it is a number.
 *
 * @param spacelessCardNumber the raw card number, without spaces
 * @param brand the {@link Card.CardBrand} to use as a separating scheme
 * @return an array of strings with the number groups, in order. If the number is not complete,
 * some of the array entries may be {@code null}.
 */

List<String> separateCardNumberGroups(
    String spacelessCardNumber, String brand) {
  if (spacelessCardNumber.length > 16) {
    spacelessCardNumber = spacelessCardNumber.substring(0, 16);
  }
  List<String> numberGroups;
  if (brand == StripeCard.AMERICAN_EXPRESS) {
    numberGroups = new List(3);

    int length = spacelessCardNumber.length;
    int lastUsedIndex = 0;
    if (length > 4) {
      numberGroups[0] = spacelessCardNumber.substring(0, 4);
      lastUsedIndex = 4;
    }

    if (length > 10) {
      numberGroups[1] = spacelessCardNumber.substring(4, 10);
      lastUsedIndex = 10;
    }

    for (int i = 0; i < 3; i++) {
      if (numberGroups[i] != null) {
        continue;
      }
      numberGroups[i] = spacelessCardNumber.substring(lastUsedIndex);
      break;
    }
  } else {
    numberGroups = List(4);
    int i = 0;
    int previousStart = 0;
    while ((i + 1) * 4 < spacelessCardNumber.length) {
      String group = spacelessCardNumber.substring(previousStart, (i + 1) * 4);
      numberGroups[i] = group;
      previousStart = (i + 1) * 4;
      i++;
    }
    // Always stuff whatever is left into the next available array entry. This handles
    // incomplete numbers, full 16-digit numbers, and full 14-digit numbers
    numberGroups[i] = spacelessCardNumber.substring(previousStart);
  }
  return numberGroups;
}
