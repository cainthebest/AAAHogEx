﻿class Utils {
	static function DivCeil(a, b) {
		return (a + b - 1) / b;
	}
}

class IntegerUtils {
	static IntMax = 2147483647;
}

class HgArray {
	array = null;

	constructor(array) {
		this.array = array;
	}


	static function AIListKey(list) {
		local a = [];
		foreach(k, v in list) {
			a.push(k);
		}
		return HgArray(a);
	}

	static function AIListKeyValue(list) {
		local a = [];
		foreach(k, v in list) {
			a.push([k, v]);
		}
		return HgArray(a);
	}

	static function Generator(gen) {
		local e;
		local a = [];
		while ((e = resume gen) != null) {
			a.push(e);
		}
		return HgArray(a);
	}

	function GetArray() {
		return array;
	}

	function Map(func) {
		local result = ::array(array.len());
		foreach(i, a in array) {
			result[i] = func(a);
		}
		return HgArray(result);
	}


	function Filter(func) {
		local result = [];
		foreach(a in array) {
			if (func(a)) {
				result.push(a)
			}
		}
		return HgArray(result);
	}

	static function _Flatten(a) {
		if (typeof a != "array") {
			return [a];
		} else {
			local result = [];
			foreach(x in a) {
				result.extend(HgArray._Flatten(x));
			}
			return result;
		}
	}

	function Flatten() {
		return HgArray(_Flatten(array));
	}

	function Sort(func) {
		local newArray = clone array;
		newArray.sort(func);
		return HgArray(newArray);
	}

	function Slice(start, end) {
		return HgArray(array.slice(start, min(end, array.len())));
	}

	function Count() {
		return array.len();
	}

	function CountOf(item) {
		local result = 0;
		foreach(a in array) {
			if (a == item) {
				result++;
			}
		}
		return result;
	}

	function GetAIList() {
		local result = AIList();
		foreach(a in array) {
			result.AddItem(a, a);
		}
		return result;
	}

	function GetAIListKeyValue() {
		local result = AIList();
		foreach(a in array) {
			result.AddItem(a[0], a[1]);
		}
		return result;
	}

	function Remove(item) {
		local result = [];
		foreach(a in array) {
			if (a != item) {
				result.push(a);
			}
		}
		return HgArray(result);
	}

	function Contains(item) {
		foreach(a in array) {
			if (a == item) {
				return true;
			}
		}
		return false;
	}

	function ToTable() {
		local result = {};
		foreach(a in array) {
			result.rawset(a, a);
		}
		return result;
	}

	function _tostring() {
		local result = "";
		foreach(e in array) {
			if (result.len() >= 1) {
				result += ",";
			}
			result += e.tostring();
		}
		return result;
	}
}

class ArrayUtils {
	function Find(array_, element) {
		foreach(i, e in array_) {
			if (e == element) {
				return i;
			}
		}
		return null;
	}

	function Remove(array_, element) {
		local idx = ArrayUtils.Find(array_, element);
		if (idx != null) {
			array_.remove(idx);
		}
	}

	function Add(array_, element) {
		if (ArrayUtils.Find(array_, element) != null) {
			return;
		}
		array_.push(element);
	}

	function Without(array_, element) {
		local result = [];
		foreach(e in array_) {
			if (e != element) {
				result.push(e);
			}
		}
		return result;
	}

	function And(a1, a2) {
		local result = [];
		foreach(e1 in a1) {
			foreach(e2 in a2) {
				if (e1 == e2) {
					result.push(e1);
				}
			}
		}
		return result;
	}

	function Or(a1, a2) {
		local t = {};
		foreach(e in a1) {
			t.rawset(e, 0);
		}
		foreach(e in a2) {
			t.rawset(e, 0);
		}
		local result = [];
		foreach(k, _ in t) {
			result.push(k);
		}
		return result;
	}

	// a1は破壊される
	function Extend(a1, a2) {
		a1.extend(a2);
		return a1;
	}

	function Reverse(a) {
		local result = [];
		local size = a.len();
		for (local i = size - 1; i >= 0; i--) {
			result.push(a[i]);
		}
		return result;
	}

	function SubArray(array_, idx, length) {
		local result = [];
		local endIdx = min(array_.len(), idx + length);
		for (local i = max(0, idx); i < endIdx; i++) {
			result.push(array_[i]);
		}
		return result;
	}

	function Shuffle(a) {
		local list = AIList();
		foreach(index, _ in a) {
			list.AddItem(index, AIBase.Rand());
		}
		list.Sort(AIList.SORT_BY_VALUE, true);
		local result = [];
		foreach(index, _ in list) {
			result.push(a[index]);
		}
		return result;
	}
}

class ListUtils {
	static function Sum(list) {
		local result = 0;
		foreach(k, v in list) {
			result += v;
		}
		return result;
	}

	static function Average(list) {
		local result = 0;
		foreach(k, v in list) {
			result += v;
		}
		return result / list.Count();
	}

	static function Clone(list) {
		local result = AIList();
		result.AddList(list);
		return result;
	}

}

class TableUtils {
	static function GetKeys(table) {
		local keys = [];
		foreach(k, v in table) {
			keys.push(k);
		}
		return keys;
	}

	static function Extend(table1, table2) {
		foreach(k, v in table2) {
			table1.rawset(k, v);
		}
	}
}

class HgTable {
	table = null;

	constructor(table) {
		this.table = table;
	}


	function _tostring() {
		local result = "";
		foreach(k, v in table) {
			if (result.len() >= 1) {
				result += ", ";
			}
			result += k + "=" + v;
		}
		return "{" + result + "}";
	}

	function Keys() {
		local result = [];
		foreach(k, v in table) {
			result.push(k);
		}
		return result;
	}

	function Values() {
		local result = [];
		foreach(k, v in tbale) {
			result.push(v);
		}
		return result;
	}

	static function Extend(table1, table2) {
		foreach(k, v in table2) {
			table1.rawset(k, v);
		}
	}

	static function FromArray(a) {
		local result = {};
		foreach(e in a) {
			result.rawset(e, 0);
		}
		return result;
	}

	static function Diff(table1, table2) {
		local result = {
			append = {},
			remove = {}
		};
		foreach(k, v in table1) {
			if (table2.rawin(k)) continue;
			result.remove.rawset(k, v); // table1にあってtable2に無い
		}
		foreach(k, v in table2) {
			if (table1.rawin(k)) continue;
			result.append.rawset(k, v); // table2にあってtable1に無い
		}
		return result;
	}


}

class DefaultTable {
	table = null;
	defFunc = null;

	constructor(defFunc, table = {}) {
		this.defFunc = defFunc;
		this.table = table;
	}

	function _get(idx) {
		if (table.rawin(idx)) {
			return table.rawget(idx);
		}
		local result = defFunc();
		table.rawset(idx, result);
		return result;
	}
}

class StringUtils {
	static function SliceMaxLen(str, length) {
		if (str.len() > length) {
			return str.slice(0, length);
		}
		return str;
	}
}

class SortedList {
	valuator = null;
	list = null;
	arr = null;

	constructor(valuator) {
		this.valuator = valuator;
		this.list = AIList();
		this.list.Sort(AIList.SORT_BY_VALUE, false); // でかい順に返す
		this.arr = [];
	}

	function Extend(arr) {
		local start = this.arr.len();
		this.arr.extend(arr);
		foreach(i, e in arr) {
			list.AddItem(start + i, valuator(e));
		}
		/*
		foreach(i,v in list) {
			local e = this.arr[i];
			if(e != null) {
				HgLog.Info("List:"+v+" "+e.dest.GetName()+"<-"+e.src.GetName()+" "+e.estimate);
			}
		}*/
	}

	function Push(item) {
		list.AddItem(this.arr.len(), valuator(item));
		this.arr.push(item);
	}

	function Peek() {
		local result = null;
		if (list.Count() >= 0) {
			local i = list.Begin();
			result = arr[i];
		}
		return result;
	}

	function PeekBottom() {
		local l = AIList();
		l.Sort(AIList.SORT_BY_VALUE, true);
		l.AddList(list);
		local result = null;
		if (l.Count() >= 0) {
			local i = l.Begin();
			result = arr[i];
		}
		return result;
	}

	function Pop() {
		local result = null;
		if (list.Count() >= 0) {
			local i = list.Begin();
			result = arr[i];
			list.RemoveTop(1);
			arr[i] = null;
		}
		return result;
	}

	function GetAll() {
		local result = [];
		foreach(i, _ in list) {
			result.push(arr[i]);
		}
		return result;
	}

	function Count() {
		return list.Count();
	}
}

class IdCounter {
	counter = null;

	constructor(initial = 1) {
		counter = initial;
	}

	function Get() {
		return counter++;
	}

	function Skip(id) {
		if (counter < id + 1) {
			counter = id + 1;
		}
	}
}

class HgLog {
	static function GetDateString() {
		return DateUtils.ToString(AIDate.GetCurrentDate());
	}

	static function Info(s) {
		AILog.Info(HgLog.GetDateString() + " " + s);
	}

	static function Warning(s) {
		AILog.Warning(HgLog.GetDateString() + " " + s);
	}

	static function Error(s) {
		AILog.Error(HgLog.GetDateString() + " " + s);
		//AIController.Break(s);
	}
}

class ExpirationTable {
	table = null;
	expiration = null;
	lastClearDate = null;

	constructor(expiration) {
		this.table = {};
		this.expiration = expiration;
		this.lastClearDate = AIDate.GetCurrentDate();
	}

	function CheckExpiration() {
		if (lastClearDate + expiration < AIDate.GetCurrentDate()) {
			clear();
		}
	}

	function rawin(e) {
		CheckExpiration();
		return table.rawin(e);
	}

	function rawget(e) {
		return table.rawget(e);
	}

	function rawset(e, v) {
		table.rawset(e, v);
	}

	function clear() {
		table.clear();
		lastClearDate = AIDate.GetCurrentDate();
	}
}

class ExpirationRawTable {
	table = null;
	expiration = null;

	constructor(expiration) {
		this.table = {};
		this.expiration = expiration;
	}

	function rawin(e) {
		if (table.rawin(e)) {
			local d = table.rawget(e);
			if (d[0] + expiration < AIDate.GetCurrentDate()) {
				return false;
			} else {
				return true;
			}
		}
		return false;
	}

	function rawget(e) {
		return table.rawget(e)[1];
	}

	function rawset(e, v) {
		table.rawset(e, [AIDate.GetCurrentDate(), v]);
	}

	function clear() {
		table.clear();
	}
}

class DateUtils {
	static function ToString(date) {
		if (date == null) {
			return "null";
		} else {
			return AIDate.GetYear(date) + "-" + AIDate.GetMonth(date) + "-" + AIDate.GetDayOfMonth(date);
		}
	}
}

class BuildUtils {
	static function BuildSafe(func, limit = 100) {
		return BuildUtils.RetryUntilFree(function(): (func) {
			return BuildUtils.WaitForMoney(func);
		}, limit);
	}

	static function RetryUntilFree(func, limit = 100, supressWarning = false) {
		local i;
		for (i = 0; i < limit; i++) {
			if (func()) {
				if (i >= 1 && !supressWarning) {
					HgLog.Info("RetryUntilFree Succeeded count:" + i);
				}
				return true;
			}
			if (AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY) {
				if (i == 0 && !supressWarning) {
					HgLog.Warning("RetryUntilFree(ERR_VEHICLE_IN_THE_WAY) limit:" + limit);
				}
				AIController.Sleep(3);
				continue;
			}
			break;
		}
		if (i == limit && !supressWarning) {
			HgLog.Warning("RetryUntilFree limit exceeded:" + limit);
		}
		return false;
	}

	static function CanTryToDemolish(tile) {
		if (AITile.IsBuildable(tile)) {
			return false;
		}
		if (!AICompany.IsMine(AITile.GetOwner(tile))) {
			return true;
		}
		if (AIRail.IsRailTile(tile) || AIBridge.IsBridgeTile(tile) || AITunnel.IsTunnelTile(tile)) {
			return !BuildedPath.Contains(tile);
		}
		if (AITile.IsStationTile(tile)) {
			return false;
		}
		return true;
	}

	static function DemolishTileUntilFree(tile) {
		return BuildUtils.RetryUntilFree(function(): (tile) {
			return AITile.DemolishTile(tile);
		});
	}


	static function CheckCost(func) {
		local cost;
		{
			local testMode = AITestMode();
			local accounting = AIAccounting();
			if (!func()) {
				if (AIError.GetLastError() != AIError.ERR_NOT_ENOUGH_CASH) {
					return false; // お金じゃない理由で失敗
				}
			}
			cost = accounting.GetCosts();
		}
		if (HogeAI.Get().IsTooExpensive(cost)) {
			return false;
		}
		return true;
	}

	static function WaitForMoney(func) {
		local cost;
		{
			local testMode = AITestMode();
			local accounting = AIAccounting();
			if (!func()) {
				if (AIError.GetLastError() != AIError.ERR_NOT_ENOUGH_CASH) {
					return false; // お金じゃない理由で失敗
				}
			}
			cost = accounting.GetCosts();
		}
		if (HogeAI.Get().IsTooExpensive(cost)) {
			HgLog.Warning("cost too expensive:" + cost);
			return false;
		}
		while (true) {
			if (!HogeAI.WaitForPrice(cost)) {
				return false;
			}
			local r = func();
			if (!r && AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) { // 事前チェックしてても失敗する事がある
				cost += HogeAI.Get().GetInflatedMoney(10000);
				continue;
			}
			return r;
		}
	}

	static function WaitForMoneyValid(func, valid) {
		local cost;
		{
			local testMode = AITestMode();
			local accounting = AIAccounting();
			local r = func();
			if (r != 0) {
				if (AIError.GetLastError() != AIError.ERR_NOT_ENOUGH_CASH) {
					return r; // お金じゃない理由で失敗
				}
			}
			cost = accounting.GetCosts();
		}
		if (HogeAI.Get().IsTooExpensive(cost)) {
			HgLog.Warning("cost too expensive:" + cost);
			return -1;
		}
		while (true) {
			if (!HogeAI.WaitForPrice(cost)) {
				return -1;
			}
			local r = func();
			if (!valid(r) && AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) { // 事前チェックしてても失敗する事がある
				cost += HogeAI.Get().GetInflatedMoney(10000);
				continue;
			}
			return r;
		}
	}

	static function BuildVehicleSafe(a, b) {
		return BuildUtils.WaitForMoneyValid(function(): (a, b) {
			return AIVehicle.BuildVehicle(a, b);
		}, function(r) {
			return AIVehicle.IsValidVehicle(r);
		});
	}

	static function BuildVehicleWithRefitSafe(a, b, c) {
		return BuildUtils.WaitForMoneyValid(function(): (a, b, c) {
			return AIVehicle.BuildVehicleWithRefit(a, b, c);
		}, function(r) {
			return AIVehicle.IsValidVehicle(r);
		});


		/*
		static function BuildVehicleWithRefitSafe(a,b,c) {
			local func = function():(a,b,c) {
				return AIVehicle.BuildVehicleWithRefit(a, b, c);
			};
			local cost;
			{
				local testMode = AITestMode();
				local accounting = AIAccounting();
				if(func() != 0) {
					if(AIError.GetLastError() != AIError.ERR_NOT_ENOUGH_CASH) {
						return null; // お金じゃない理由で失敗
					}
				}
				cost = accounting.GetCosts();
			}
			while(true) {
				if(!HogeAI.WaitForPrice(cost)) {
					return null;
				}
				local r = func();
				if(!AIVehicle.IsValidVehicle(r) && AIError.GetLastError() == AIError.ERR_NOT_ENOUGH_CASH) { // 事前チェックしてても失敗する事がある
					cost += HogeAI.Get().GetInflatedMoney(10000);
					continue;
				}
				return r;
			}
		}*/

	}

	static function LowerTileSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AITile.LowerTile(a, b);
		});

	}

	static function RaiseTileSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AITile.RaiseTile(a, b);
		});

	}

	static function BuildBridgeSafe(a, b, c, d) {
		return BuildUtils.WaitForMoney(function(): (a, b, c, d) {
			return AIBridge.BuildBridge(a, b, c, d);
		});
	}

	static function BuildTunnelSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AITunnel.BuildTunnel(a, b);
		});
	}

	static function BuildRailDepotSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AIRail.BuildRailDepot(a, b);
		});
	}

	static function BuildRailTrackSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AIRail.BuildRailTrack(a, b);
		});

	}

	static function BuildSignalSafe(a, b, c) {
		return BuildUtils.WaitForMoney(function(): (a, b, c) {
			return AIRail.BuildSignal(a, b, c);
		});

	}

	static function RemoveSignalSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AIRail.RemoveSignal(a, b);
		});

	}

	static function RemoveRoadFullSafe(a, b) {
		return BuildUtils.WaitForMoney(function(): (a, b) {
			return AIRoad.RemoveRoadFull(a, b);
		});
	}

	static function DemolishTileSafe(a) {
		return BuildUtils.WaitForMoney(function(): (a) {
			return AITile.DemolishTile(a);
		});
	}

	static function RemoveRoadStationSafe(tile) {
		return BuildUtils.BuildSafe(function(): (tile) {
			return AIRoad.RemoveRoadStation(tile);
		});
	}

	static function BuildDockSafe(a, b) {
		return BuildUtils.BuildSafe(function(): (a, b) {
			return AIMarine.BuildDock(a, b);
		});
	}
	static function BuildCanalSafe(a) {
		return BuildUtils.BuildSafe(function(): (a) {
			return AIMarine.BuildCanal(a);
		});
	}


	static function RemoveBridgeUntilFree(p1) {
		return BuildUtils.RetryUntilFree(function(): (p1) {
			return AIBridge.RemoveBridge(p1);
		});
	}
	static function RemoveTunnelUntilFree(p1) {
		return BuildUtils.RetryUntilFree(function(): (p1) {
			return AITunnel.RemoveTunnel(p1);
		});
	}


	static function RemoveAirportSafe(tile) {
		return BuildUtils.BuildSafe(function(): (tile) {
			return AIAirport.RemoveAirport(tile);
		});
	}

	static function GetClearWaterCost() {
		local testMode = AITestMode();
		local accounting = AIAccounting();
		local tile = AIMap.GetTileIndex(1, 1);
		if (AITile.IsWaterTile(tile)) {
			AITile.RaiseTile(tile, AITile.SLOPE_S);
			return accounting.GetCosts();
		}
		return 0; //TODO 他のタイルも調べる
	}


}


class Container {
	instance = null;

	constructor(instance = null) {
		this.instance = instance;
	}

	function Get() {
		return instance;
	}

	function GetName() {
		return "This is container";
	}
}

class GetterFunction {
	func = null;

	constructor(func) {
		this.func = func;
	}

	function Get() {
		return func();
	}
}

class GeneratorContainer {
	instance = null;
	gen = null;

	constructor(gen) {
		this.gen = gen;
	}

	function Get() {
		if (instance == null) {
			instance = gen();
		}
		return instance;
	}
}


class PerformanceCounter {
	static table = {};

	startDate = null;
	startTick = null;
	startOps = null;
	totalDate = null;
	totalTick = null;
	totalOps = null;
	count = null;

	static function Start(name) {
		local counter;
		if (!PerformanceCounter.table.rawin(name)) {
			counter = PerformanceCounter();
			counter.totalDate = 0;
			counter.totalTick = 0;
			counter.totalOps = 0;
			counter.count = 0;
			PerformanceCounter.table.rawset(name, counter);
		} else {
			counter = PerformanceCounter.table.rawget(name);
		}
		counter.startDate = AIDate.GetCurrentDate();
		counter.startTick = AIController.GetTick();
		counter.startOps = AIController.GetOpsTillSuspend();
		return counter;
	}

	function Stop() {
		local tick = AIController.GetTick() - startTick;
		totalDate += AIDate.GetCurrentDate() - startDate;
		totalTick += tick;
		totalOps += tick * 10000 + (startOps - AIController.GetOpsTillSuspend());
		count++;
	}

	static function Print() {
		foreach(name, counter in PerformanceCounter.table) {
			HgLog.Info(name + " " + counter.totalDate + "[days] " + counter.totalTick + "[ticks] " + counter.totalOps + "[ops] " + counter.count + "[times]");
		}
		PerformanceCounter.table.clear();
	}

	static function Clear() {
		PerformanceCounter.table.clear();
	}
}


class HgVehicleType {
	vehicleType = null;

	constructor(vehicleType) {
		this.vehicleType = vehicleType;
	}

	function _tostring() {
		return VehicleUtils.GetTypeName(vehicleType);
	}
}

class VehicleUtils {
	static function GetTypeName(vehicleType) {
		switch (vehicleType) {
			case AIVehicle.VT_RAIL:
				return "Train";
			case AIVehicle.VT_ROAD:
				return "Road";
			case AIVehicle.VT_WATER:
				return "Water";
			case AIVehicle.VT_AIR:
				return "Air";
			case AIVehicle.VT_INVALID:
				return "Invalid vehicle type";
		}
		HgLog.Error("VehicleUtils.GetTypeName:" + vehicleType);
	}

	static function GetCargoWeight(cargo, quantity) { // 鉄道用
		local result = VehicleUtils.GetCommonCargoWeight(cargo, quantity);
		if (AICargo.IsFreight(cargo)) {
			result *= HogeAI.Get().GetFreightTrains();
		}
		return result;
	}


	static function GetCommonCargoWeight(cargo, quantity) {
		if (HogeAI.Get().openttdVersion >= 13) {
			return AICargo.GetWeight(cargo, quantity)
		}

		local result;
		local label = AICargo.GetCargoLabel(cargo);
		if (AICargo.HasCargoClass(cargo, AICargo.CC_PASSENGERS)) {
			result = quantity / 16;
		} else if (AICargo.HasCargoClass(cargo, AICargo.CC_MAIL)) {
			result = quantity / 4;
		} else if (AICargo.HasCargoClass(cargo, AICargo.CC_EXPRESS) &&
			(AICargo.GetTownEffect(cargo) == AICargo.TE_GOODS || AICargo.GetTownEffect(cargo) == AICargo.TE_WATER /*for FIRS*/ )) {
			result = quantity / 2;
		} else if (label == "LVST") {
			result = quantity / 6;
		} else if (label == "VALU") {
			result = quantity / 10;
		} else {
			result = quantity;
		}

		return result;
	}

	static function GetSlopeForce(slopedWeight, totalWeight) {
		return slopedWeight * HogeAI.Get().GetTrainSlopeSteepness() * 100 + totalWeight * 10 + totalWeight * 15;
	}

	static function GetAirDrag(speed, maxSpeed, numParts) {
		local airDragValue = min(192, max(1, 2048 / maxSpeed));
		local airDragCoefficient = 14 * airDragValue * (1 + numParts * 3 / 20) / 1000.0;
		return (airDragCoefficient * speed * speed).tointeger();
	}

	static function GetRoadSlopeForce(weight) {
		return weight * HogeAI.Get().GetRoadvehSlopeSteepness() * 100 + weight * 10 + weight * 75;
	}

	static function GetForce(maxTractiveEffort, power, requestSpeed) {
		if (requestSpeed == 0) {
			HgLog.Warning("GetForce requestSpeed == 0");
			requestSpeed = 1;
		}
		return min((maxTractiveEffort * 1000), power * 746 * 18 / requestSpeed / 5);
	}

	static function GetAcceleration(slopeForce, requestSpeed, tractiveEffort, power, towalWeight) {
		// (km/h per 0.5tick) / 256 (1day=74tick)
		// 1tickに2回1/256単位で速度更新を行う。1日経つと、a*148/256だけ速度が増加
		local engineForce = VehicleUtils.GetForce(tractiveEffort, power, requestSpeed);
		return (engineForce - slopeForce) / (towalWeight * 4);
	}

	static function GetMaxSlopeForce(maxSlopes, lengthWeights, towalWeight) {
		local maxSlopedWeight = 0;
		if (maxSlopes > 0) {
			local lwLen = lengthWeights.len();
			local maxSlopesLen = 16 * maxSlopes;
			for (local i = 0; i < lwLen; i++) {
				local w = 0;
				local l = 0;
				do {
					w += lengthWeights[i][1];
					i++;
					if (i >= lwLen) {
						break;
					}
					l += (lengthWeights[i - 1][0] + lengthWeights[i][0]) / 2;
				} while (l < maxSlopesLen); //iを戻していないので不正確な可能性があるが、そのお陰で大分高速化している
				maxSlopedWeight = max(maxSlopedWeight, w);
			}
		}
		//HgLog.Info("maxSlopedWeight:"+maxSlopedWeight);
		return VehicleUtils.GetSlopeForce(maxSlopedWeight, towalWeight);
	}

	static function AdjustTrainScoreBySlope(score, engine, start, end, isBiDirectional = false) {
		local considerSlopeLevel = 0;
		local slopeSteepness = HogeAI.Get().GetTrainSlopeSteepness();
		if (AIEngine.GetMaxTractiveEffort(engine) < slopeSteepness * 50) {
			considerSlopeLevel = 2;
		} else if (HogeAI.Get().mountain && AIEngine.GetPower(engine) < slopeSteepness * 600) {
			considerSlopeLevel = 1;
		} else {
			return score;
		}
		local slopeLevel = HgTile(start).GetSlopeLevel(HgTile(end));
		if (considerSlopeLevel == 2) {
			score = score * 8 / (8 + slopeLevel - 4);
		} else {
			score = score * 16 / (16 + max(0, slopeLevel - 4));
		}
		if (isBiDirectional) {
			return VehicleUtils.AdjustTrainScoreBySlope(score, engine, end, start, false);
		}
		return score;
	}

	static function GetDays(distance, speed) {
		return max(1, distance * 664 / speed / 24 / HogeAI.Get().GetDayLengthFactor());
	}

	static function GetSpeed(distance, days) {
		return distance * 664 / (days * HogeAI.Get().GetDayLengthFactor() * 24);
	}

	static function GetDistance(speed, days) {
		return speed * (days * HogeAI.Get().GetDayLengthFactor() * 24) / 664;
	}

	static function ToString(vehicleType) {
		switch (vehicleType) {
			case AIVehicle.VT_RAIL:
				return "Rail";
			case AIVehicle.VT_WATER:
				return "Water";
			case AIVehicle.VT_ROAD:
				return "Road";
			case AIVehicle.VT_AIR:
				return "Air";
		}
	}
}

class CargoUtils {
	static isDelivableCache = ExpirationTable(365);
	static supplyCargos = {};

	/*TODO: rateでの補正は呼び出し元でやる
	static function GetStationRate(cargo, maxSpeed) { // 255 == 100%
		local result = 170 + min(43,max(0,(maxSpeed - 85) / 4));
		result += 33; // 新品で計算
		if(HogeAI.Get().ecs) {
			if(!CargoUtils.IsPaxOrMail(cargo) && result < (HogeAI.Get().IsRich() ? 153 : 179)) {
				result /= 4; // 70%いかない輸送手段はゴミ
			}
		}
		return result;
	}*/

	static function GetStationRate(maxSpeed) {
		local stationRate = max((min(255, maxSpeed) - 85) / 4, 0);
		//stationRate += 33; // 新品で計算
		stationRate += HogeAI.Get().IsRich() ? 26 : 0; //彫像
		return stationRate;
	}

	static function GetReceivedProduction(prodictionPerMonth, initialRate, day, maxSpeed) {
		local production = prodictionPerMonth.tofloat() / 30;

		local iniRate = initialRate / 255.0;
		local endRate = (CargoUtils.GetStationRate(maxSpeed) + 170) / 255.0;
		local a = 0.003137; //0.8 / 255;
		local t0 = abs(endRate - iniRate) / a;

		if (day <= t0) {
			return ((2 * iniRate + day * a) * day / 2 * production).tointeger();
		} else {
			return (((iniRate + endRate) * t0 / 2 + (day - t0) * endRate) * production).tointeger();
		}
	}

	static function GetStationRateWaitTimeFullLoad(prodictionPerMonth, initialRate, capacity, maxSpeed) {
		local prodPerDay = prodictionPerMonth.tofloat() / 30;
		local iniRate = initialRate / 255.0;
		local endRate = (CargoUtils.GetStationRate(maxSpeed) + 170) / 255.0;
		local a = 0.0078; // 0.78%/day //0.003137; //0.8 / 255;
		local t0 = abs(endRate - iniRate) / a; // rateが上がりきるまでの日数
		local c0 = (iniRate + endRate) / 2 * t0 * prodPerDay; // t0の間に増えるproduction
		if (capacity < c0) {
			local iniProd = iniRate * prodPerDay;
			//local aProd = a * prodPerDay;
			//local t = (-iniProd+pow(iniProd * iniProd + 2 * aProd * capacity, 0.5)) / aProd;
			local t = capacity / (prodPerDay * iniRate); // 軽量化のための近似
			local rate = (iniRate + t * a) * 255;
			if (rate > endRate) rate = endRate;
			//HgLog.Info("FullLoad 1 prod:"+prodPerDay+" capa:"+capacity+" iniProd:"+iniProd+" rate:"+(rate/255)+" t:"+t);
			return [rate.tointeger(), t.tointeger()];
		} else {
			local t = t0 + (capacity - c0) / (endRate * prodPerDay); // rateが上がりきる日数 + 上がりきってから溜まるまでの日数
			local rate = endRate * 255;
			//HgLog.Info("FullLoad 2 prod:"+prodPerDay+" capa:"+capacity+" iniRate:"+iniRate+" rate:"+(rate/255)+" t:"+t);
			return [rate.tointeger(), t.tointeger()];
		}
	}

	static function GetStationRateStock(cargo, production, initialRate, vehicleType, maxSpeed, iniIntervalDays) {
		local intervalDays = iniIntervalDays;
		local productionPerDay = production.tofloat() / 30;
		local stationRate = CargoUtils.GetStationRate(maxSpeed);
		local result = 0;
		local oldRate = initialRate;
		// 評価の低下や、stockの増加による在庫廃棄は計算していない
		foreach(d in [
			[7, 130],
			[8, 95],
			[15, 50],
			[22, 25],
			[1000000, 0]
		]) {
			local day = d[0] * (vehicleType == AIVehicle.VT_WATER ? 4 : 1);
			local rate = stationRate + d[1] + CargoUtils.GetStockStationRate(result); // stockの増加によって途中で下がるrate分はとりあえず無視
			local truncate = 0;
			if (rate <= 64) { // セクション中での変化には未対応
				if (result >= 200) {
					truncate = 3;
				} else if (result >= 100) {
					truncate = 2;
				}
			}
			local reachDay = abs(oldRate - rate) * 5 / 4; // 2.5日あたり最大2変動
			if (day < reachDay) {
				rate = oldRate + (rate > oldRate ? 1 : -1) * day * 4 / 5;
			}
			oldRate = rate;
			local receiveDay = min(intervalDays, day);
			local receive = (receiveDay * (oldRate + rate) / 2 * productionPerDay / 255).tointeger();
			if (HogeAI.Get().ecs && !CargoUtils.IsPaxOrMail(cargo)) {
				if (rate < 179 /*70%*/ ) {
					receive /= 4; // ecsでは70%いかないと生産量がとても下がる
				}
			} else {
				if (AICargo.HasCargoClass(cargo, AICargo.CC_BULK) && rate >= 204 /*80%*/ ) {
					receive = receive * 15 / 10; // 一次産業は80%超えると生産量がどんどん成長する
				}
			}
			result += receive - truncate * receiveDay;
			intervalDays -= day;
			if (intervalDays <= 0) {
				return [rate, result];
			}
		}
		assert(false);
	}

	static function GetStockStationRate(stock) {
		if (stock <= 100) {
			return 40;
		}
		if (stock <= 300) {
			return 30;
		}
		if (stock <= 600) {
			return 10;
		}
		if (stock <= 1000) {
			return 0;
		}
		if (stock <= 1500) {
			return -35;
		}
		return -90;
	}

	// 年間の予想収益
	// waitingDays: 積み下ろし時間
	/*
	static function GetCargoIncome(distance, cargo, speed, waitingDays=0, isBidirectional=false) {
		if(speed<=0) {
			return 0;
		}
		local days = max(1, distance*664/speed/24);

		local income = AICargo.GetCargoIncome(cargo,distance,days);
		return income * 365 / (days * 2 + waitingDays) * (isBidirectional ? 2 : 1);
	}*/

	static function IsPaxOrMail(cargo) {
		foreach(c in HogeAI.Get().GetPaxMailCargos()) {
			if (c == cargo) return true;
		}
		return false;
	}

	static function IsDelivable(cargo) {
		if (CargoUtils.isDelivableCache.rawin(cargo)) {
			return CargoUtils.isDelivableCache.rawget(cargo);
		}
		foreach(vt, _ in Route.GetAvailableVehicleTypes()) {
			local engineList = AIEngineList(vt);
			engineList.Valuate(AIEngine.CanRefitCargo, cargo);
			engineList.KeepValue(1);
			engineList.Valuate(AIEngine.IsBuildable);
			engineList.KeepValue(1);
			if (engineList.Count() >= 1) {
				CargoUtils.isDelivableCache.rawset(cargo, true);
				return true;
			}
		}
		CargoUtils.isDelivableCache.rawset(cargo, false);
		return false;
	}

	static function IsSupplyCargo(cargo) {
		if (!CargoUtils.supplyCargos.rawin("initialized")) {
			foreach(industryType, _ in AIIndustryTypeList()) {
				if (AIIndustryType.IsRawIndustry(industryType)) {
					foreach(cargo, _ in AIIndustryType.GetAcceptedCargo(industryType)) {
						CargoUtils.supplyCargos.rawset(cargo, cargo);
					}
				}
			}
			CargoUtils.supplyCargos.rawset("initialized", true);
		}
		return CargoUtils.supplyCargos.rawin(cargo);
	}

}

class Serializer {
	static nameClass = {};

	static function Save(instance_) {
		if (instance_ == null) {
			return null;
		}
		return instance_.Save();
	}

	static function Load(data) {
		if (data == null) {
			return data;
		}
		return Serializer.nameClass[data.name].Load(data);
	}
}