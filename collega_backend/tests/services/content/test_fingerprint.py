from app.services.content.fingerprint import item_hash, normalize_item_pages, page_hash


def test_page_hash_is_sha256_of_raw_text():
    assert page_hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert page_hash("abc ") != page_hash("abc")


def test_page_numbers_at_page_edges_and_spaces_are_ignored():
    pages = ["12\nItem 304  Tumeurs\n\n  Le   foie\tsain\nPage 12 / 436", "13 sur 40\nSuite\nFin\n  7 "]
    assert normalize_item_pages(pages) == "Item 304 Tumeurs\nLe foie sain\nSuite\nFin"


def test_item_hash_ignores_page_renumbering():
    before = ["Tumeurs du foie\nLe foie\nMétastases\n233", "234\nSuite\nconclusion"]
    after = ["Tumeurs du foie\nLe foie\nMétastases\n241", "242\nSuite\nconclusion"]
    assert item_hash(before) == item_hash(after)


def test_number_alone_in_page_body_is_content():
    """Une dose seule sur sa ligne, au milieu d'une page, compte : si elle change, on régénère."""
    body = ["Titre", "Posologie", "Adulte", "Dose (mg)", "{dose}", "par jour", "Enfant", "Surveillance", "Fin"]
    before = ["\n".join(body).replace("{dose}", "500")]
    after = ["\n".join(body).replace("{dose}", "1000")]
    assert item_hash(before) != item_hash(after)


def test_item_hash_changes_when_content_changes():
    assert item_hash(["Le foie\nMétastases"]) != item_hash(["Le foie\nMétastases hépatiques"])


def test_numbers_inside_a_line_are_kept():
    assert item_hash(["Dose 233 mg"]) != item_hash(["Dose 234 mg"])
