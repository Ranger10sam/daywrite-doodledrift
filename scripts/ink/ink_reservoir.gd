class_name InkReservoir
extends RefCounted
## Refund only a stroke's unregenerated debit. This prevents refund banking.
var capacity: float = 100.0
var amount: float = 100.0
var regeneration: float = 5.0
var total_spent: float = 0.0
var total_refunded: float = 0.0
var debt: Array[Dictionary] = []
var next_id: int = 1

func configure(maximum: float, regen: float) -> void:
	capacity = maximum
	amount = capacity
	regeneration = regen
	total_spent = 0.0
	total_refunded = 0.0
	debt.clear()
	next_id = 1

func begin_stroke() -> int:
	var id := next_id
	next_id += 1
	debt.append({"id": id, "outstanding": 0.0, "cost": 0.0})
	return id

func spend(id: int, requested: float) -> float:
	var accepted := minf(amount, maxf(0.0, requested))
	amount -= accepted
	total_spent += accepted
	for item in debt:
		if int(item.id) == id:
			item.outstanding += accepted
			item.cost += accepted
			break
	return accepted

func tick(delta: float) -> void:
	var restored := minf(capacity - amount, regeneration * maxf(delta, 0.0))
	amount += restored
	# Credit oldest outstanding drawing debit first, including destroyed strokes.
	for item in debt:
		var credit := minf(float(item.outstanding), restored)
		item.outstanding -= credit
		restored -= credit
		if restored <= 0.00001:
			break

func refund(id: int) -> float:
	for i in range(debt.size()):
		if int(debt[i].id) == id:
			var credit := minf(float(debt[i].outstanding), capacity - amount)
			amount += credit
			# Net use measures accepted distance minus physically removed distance.
			total_refunded += float(debt[i].cost)
			debt.remove_at(i)
			return credit
	return 0.0

func pickup(units: float) -> void:
	# A pickup is simulation credit and must settle the refund ledger as regen does.
	var old_rate := regeneration
	regeneration = maxf(0.0, units)
	tick(1.0)
	regeneration = old_rate

func net_used() -> float:
	return maxf(0.0, total_spent - total_refunded)
