from app.services.notifications.apns_service import completion_message, failure_message


def test_first_import_message():
    assert completion_message(None) == ("Fiches prêtes", "Tes fiches t’attendent dans Collega.")


def test_reimport_with_changes():
    s = {"changed": 3, "added": 1, "removed": 0, "unchanged": 20, "claude_calls": 4, "quota_refunded": False}
    assert completion_message(s) == ("Fiches mises à jour", "3 items mis à jour, 1 nouveau, 20 inchangés.")


def test_singular_and_plural():
    s = {"changed": 1, "added": 0, "removed": 2, "unchanged": 1}
    assert completion_message(s)[1] == "1 item mis à jour, 2 supprimés, 1 inchangé."
    s = {"changed": 0, "added": 2, "removed": 1, "unchanged": 0}
    assert completion_message(s)[1] == "2 nouveaux, 1 supprimé."


def test_reimport_without_changes_quota_refunded():
    s = {"changed": 0, "added": 0, "removed": 0, "unchanged": 24, "claude_calls": 0, "quota_refunded": True}
    assert completion_message(s) == (
        "Aucun changement",
        "Aucun changement dans ce PDF : ton réimport n’a pas été décompté.",
    )


def test_reimport_without_changes_quota_kept():
    s = {"changed": 0, "added": 0, "removed": 0, "unchanged": 24, "claude_calls": 1, "quota_refunded": False}
    assert completion_message(s) == ("Aucun changement", "Aucun changement dans ce PDF.")


def test_failure_messages():
    assert failure_message(True, "ton collège n°34") == (
        "Réimport interrompu",
        "Le réimport de ton collège n°34 n’a pas abouti. Tes fiches actuelles sont intactes.",
    )
    assert failure_message(False, "ton collège n°34") == (
        "Import interrompu",
        "L’import de ton collège n°34 n’a pas abouti. Relance-le depuis l’app.",
    )
