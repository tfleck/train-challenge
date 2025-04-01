import pytest

from trainchallenge.common import get_next_after_match


def test_get_next_after_match_basic():
    arr = ["a", "b", "c", "d"]
    result = get_next_after_match(arr, "b")
    assert result == "c", "Should return the element after the target"


def test_get_next_after_match_target_not_found():
    arr = ["a", "b", "c", "d"]
    with pytest.raises(ValueError, match="Target x not found in the array."):
        get_next_after_match(arr, "x")


def test_get_next_after_match_target_is_last():
    arr = ["a", "b", "c", "d"]
    with pytest.raises(ValueError, match="Target d is the last element in the array."):
        get_next_after_match(arr, "d")


def test_get_next_after_match_target_is_second_last():
    arr = ["a", "b", "c", "d"]
    result = get_next_after_match(arr, "c")
    assert result == "d", "Should return the last element if the target is the second last"


def test_get_next_after_match_empty_array():
    arr = []
    with pytest.raises(ValueError, match="Target x not found in the array."):
        get_next_after_match(arr, "x")


def test_get_next_after_match_single_element_array():
    arr = ["a"]
    with pytest.raises(ValueError, match="Target a is the last element in the array."):
        get_next_after_match(arr, "a")


def test_get_next_after_match_duplicate_targets():
    arr = ["a", "b", "c", "b", "d"]
    result = get_next_after_match(arr, "b")
    assert result == "c", "Should return the element after the first occurrence of the target"


def test_get_next_after_match_numeric_elements():
    arr = ["1", "2", "3", "4"]
    result = get_next_after_match(arr, "2")
    assert result == "3", "Should work with numeric strings"


def test_get_next_after_match_special_characters():
    arr = ["@", "#", "$", "%"]
    result = get_next_after_match(arr, "#")
    assert result == "$", "Should work with special characters"


def test_get_next_after_match_case_sensitivity():
    arr = ["a", "B", "c", "D"]
    with pytest.raises(ValueError, match="Target b not found in the array."):
        get_next_after_match(arr, "b")
    result = get_next_after_match(arr, "B")
    assert result == "c", "Should be case-sensitive"
