extends Node
## Replace this adapter with verified Google Play Billing purchase acknowledgement
## and restoration before shipping a premium unlock. Progress imports never grant it.
signal entitlement_changed

func has_premium() -> bool:
	# Development builds expose the entire campaign for authoring and QA.
	# No exported release save, setting, or button can enable premium access.
	return OS.is_debug_build() or OS.has_feature("editor")

func can_access_world(biome: int) -> bool:
	return biome == 0 or has_premium()

func request_purchase() -> String:
	return "Premium purchase is not available in this build. Google Play Billing integration is required before release."

func restore_purchases() -> String:
	return "Purchase restoration is not available until Google Play Billing is connected."
