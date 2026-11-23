extends RefCounted
## Deterministic bounded gameplay hydraulics, not an engineering/clinical model.
const PRIMARY := [0.0, .35, .70, 1.0]
const DIVERSION := [0.0, .25, .55, .80]
const GAIN := [.55, .78, 1.0, 1.18]
const OSCILLATION := [.18, .12, 0.0, .22]
var primary := 3
var regulator := 2
var bypass := 3
func configure(values: Dictionary) -> void:
	primary = int(values.primary)
	regulator = int(values.regulator)
	bypass = int(values.bypass)
func evidence() -> Dictionary:
	var inlet: float = PRIMARY[primary]
	var diversion: float = DIVERSION[bypass]
	var pressure: float = inlet * (1.0 - diversion) * GAIN[regulator]
	var amplitude: float = inlet * (OSCILLATION[regulator] + diversion * .10)
	var flow := pressure * .95
	return {"inlet_flow": inlet, "bypass_flow": inlet * diversion,
		"pressure": pressure, "flow": flow, "amplitude": amplitude,
		"safe": pressure >= .58 and pressure <= 1.05 and flow >= .55 and amplitude <= .06}
