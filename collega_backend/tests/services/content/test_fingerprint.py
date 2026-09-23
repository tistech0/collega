from app.services.content.fingerprint import item_hash, normalize_item_text, page_hash


def test_page_hash_is_sha256_of_raw_text():
    assert page_hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert page_hash("abc ") != page_hash("abc")


def test_normalization_drops_page_numbers_blank_lines_and_extra_spaces():
    raw = "Item 304  Tumeurs\n\n233\n  Le   foie\tsain\nPage 12 / 436\n12 sur 40\n  7 \nFin"
    assert normalize_item_text(raw) == "Item 304 Tumeurs\nLe foie sain\nFin"


def test_item_hash_ignores_page_renumbering():
    before = "Tumeurs du foie\n233\nLe foie\n234\nMétastases"
    after = "Tumeurs du foie\n241\nLe foie\n242\nMétastases"
    assert item_hash(before) == item_hash(after)


def test_item_hash_changes_when_content_changes():
    assert item_hash("Le foie\nMétastases") != item_hash("Le foie\nMétastases hépatiques")


def test_numbers_inside_a_line_are_kept():
    assert item_hash("Dose 233 mg") != item_hash("Dose 234 mg")
