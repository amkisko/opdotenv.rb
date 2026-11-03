# 1Password CLI template update limitation

## Participants

Andrei Makarov (@amkisko)

## Dependency

1Password CLI v2 is an external executable used by OpClient, not a locked Ruby dependency.

## Symptom

The vendor documents that editing an item through a JSON template overwrites passkeys. OpClient uses that supported stdin interface to keep exported secret values out of process arguments. Existing-item exports therefore support dedicated configuration items without passkeys.

## Evidence

The official item edit reference documents stdin template updates and explicitly warns that JSON templates do not support passkeys. No live vault, account or passkey was used during this audit. The documentation does not establish a stable passkey discriminator in the item-get JSON contract, so an inferred field check was not added.

Claims review outcome: supported for the documented template restriction and stdin interface; runtime detection of passkeys remains unverifiable from that reference. The contrary check considered preserving unknown JSON fields, but the vendor's template warning still applies. This review shares the implementation context; independent code review separately checked the stdin change.

## Suggested fix

Use dedicated configuration items. The README export section and release notes state this restriction before the export examples. A future adapter that updates individual fields while preserving passkeys needs a documented provider contract and integration tests; do not infer support from JSON round-tripping alone.

## Next

Verify the provider contract and add a safe adapter before supporting exports into passkey-containing items. Do not test on a live vault without authorization naming that target and action.

## Source

- https://www.1password.dev/cli/reference/management-commands/item#edit-an-item-using-a-template
- ../issues/20261028093000_engineering-release-audit.md
- ../../README.md
