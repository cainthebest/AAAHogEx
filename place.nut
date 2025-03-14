﻿class PlaceProduction {
	static instance = GeneratorContainer(function() {
		return PlaceProduction();
	});

	static function Get() {
		return PlaceProduction.instance.Get();
	}

	static PIECE_SIZE = 256;

	pieceNumX = null;
	pieceNumY = null;
	largePieceNumX = null;
	largePieceNumY = null;

	lastCheckMonth = null;
	history = null;
	currentProduction = null;
	cargoProductionInfos = {};
	cargoAcceptInfos = {};
	tooManyProducingIndustries = {};

	constructor() {
		history = {};
		currentProduction = {};
		pieceNumX = Utils.DivCeil(AIMap.GetMapSizeX(), PlaceProduction.PIECE_SIZE);
		pieceNumY = Utils.DivCeil(AIMap.GetMapSizeY(), PlaceProduction.PIECE_SIZE);
		largePieceNumX = Utils.DivCeil(pieceNumX, 4);
		largePieceNumY = Utils.DivCeil(pieceNumY, 4);
	}

	static function Save(data) {
		data.placeProduction <- {
			lastCheckMonth = lastCheckMonth
			history = history
			currentProduction = currentProduction
			tooManyProducingIndustries = tooManyProducingIndustries
		};
	}

	static function Load(data) {
		local t = data.placeProduction;
		lastCheckMonth = t.lastCheckMonth;
		history = t.history;
		currentProduction = t.currentProduction;
		tooManyProducingIndustries = t.tooManyProducingIndustries;
	}

	function GetCurrentMonth() {
		local currentDate = AIDate.GetCurrentDate();
		return (AIDate.GetMonth(currentDate) - 1) + AIDate.GetYear(currentDate) * 12;
	}

	function Check() {
		local currentMonth = GetCurrentMonth();
		if (lastCheckMonth == null || lastCheckMonth < currentMonth) {
			foreach(cargo, v in AICargoList()) {
				if (tooManyProducingIndustries.rawin(cargo)) {
					continue;
				}
				local list = AIIndustryList_CargoProducing(cargo);
				if (list.Count() >= 1) {
					local industryType = AIIndustry.GetIndustryType(list.Begin());
					if (!AIIndustryType.IsProcessingIndustry(industryType)) {
						tooManyProducingIndustries.rawset(cargo, true);
						continue;
					}
				}
				if (list.Count() >= 1000) {
					HgLog.Warning("industries of producing[" + AICargo.GetName(cargo) + "] are too many (" + list.Count() + ")");
					tooManyProducingIndustries.rawset(cargo, true);
					continue;
				}
				list.Valuate(function(industry): (history, currentProduction, cargo) {
					local production = AIIndustry.GetLastMonthProduction(industry, cargo);
					local key = industry + "-" + cargo;
					if (history.rawin(key)) {
						history[key].push(production);
					} else {
						history.rawset(key, [production]);
					}
					currentProduction.rawset(key, -1);
					return 0;
				});
			}
			lastCheckMonth = currentMonth;
		}
		/*

						foreach(industry,v in AIIndustryList_CargoProducing(cargo)) {
							local production = AIIndustry.GetLastMonthProduction (industry, cargo);
							//HgLog.Info("GetLastMonthProduction "+AIIndustry.GetName(industry)+" "+AICargo.GetName(cargo)+" "+production);
							local key = industry+"-"+cargo;
							if(!history.rawin(key)) {
								history[key] <- [1];
							}
							local a = history[key];
							if(a.len() < 13) {
								a.push(production);
							} else {
								a[a[0]] = production;
							}
							a[0] = a[0] == 12 ? 1 : a[0] + 1;
							currentProduction.rawset(key, -1);
						}
					}
					lastCheckMonth = currentMonth;
				}*/
	}

	function GetLastMonthProduction(industry, cargo) {
		if (tooManyProducingIndustries.rawin(cargo)) {
			return AIIndustry.GetLastMonthProduction(industry, cargo);
		}
		Check();
		local key = industry + "-" + cargo;
		if (!history.rawin(key)) {
			return 0;
		}
		if (currentProduction.rawin(key)) {
			local result = currentProduction[key];
			if (result != -1) {
				return result;
			}
		}
		local productions = history[key];
		local l = productions.len();
		if (l == 0) {
			return 0;
		}
		if (l > 12) {
			productions = productions.slice(l - 12, l);
			history[key] = productions;
		}
		local sum = 0;
		foreach(p in productions) {
			sum += p;
		}
		local result = sum / productions.len();
		currentProduction.rawset(key, result);
		return result;
	}


	function ClearCargoInfos() { // HogeAI.GetMaxCargoPlaces()から呼ばれる
		cargoProductionInfos.clear();
		cargoAcceptInfos.clear();
	}

	function GetProductionInfos(cargo) {
		if (!cargoProductionInfos.rawin(cargo)) {
			cargoProductionInfos.rawset(cargo, CalculateProductionInfos(cargo));
		}
		return cargoProductionInfos[cargo];
	}

	function GetAcceptInfos(cargo) {
		if (!cargoAcceptInfos.rawin(cargo)) {
			cargoAcceptInfos.rawset(cargo, CalculateAcceptInfos(cargo));
		}
		return cargoAcceptInfos[cargo];
	}

	function GetPieceIndex(tile) {
		return (AIMap.GetTileX(tile) - 1) / PlaceProduction.PIECE_SIZE + (AIMap.GetTileY(tile) - 1) / PlaceProduction.PIECE_SIZE * pieceNumX;
	}


	function CalculateAcceptInfos(cargo) {
		local pieceInfos = array(pieceNumX * pieceNumY);
		foreach(place in Place.GetCargoPlaces(cargo, false)) {
			local pieceIndex = GetPieceIndex(place.GetLocation());
			local pieceInfo;
			if (pieceInfos[pieceIndex] == null) {
				pieceInfo = {
					count = 0
					places = []
				};
				pieceInfos[pieceIndex] = pieceInfo;
			} else {
				pieceInfo = pieceInfos[pieceIndex]
			}
			pieceInfo.count++;
			pieceInfo.places.push(place);
		}
		return pieceInfos;
	}

	function CalculateProductionInfos(cargo) {
		local pieceInfos = array(pieceNumX * pieceNumY);
		foreach(i, _ in pieceInfos) {
			pieceInfos[i] = {
				sum = 0
				count = 0
				usable = true //使ってない？
				dirty = false
				places = []
			};
		}
		foreach(place in Place.GetCargoPlaces(cargo, true)) {
			if (place.GetLastMonthTransportedPercentage(cargo) > 0) {
				continue;
			}
			local prod = place.GetLastMonthProduction(cargo);
			local pieceIndex = GetPieceIndex(place.GetLocation());
			local pieceInfo = pieceInfos[pieceIndex];
			pieceInfo.sum += prod;
			pieceInfo.count++;
			pieceInfo.places.push(place);
		}
		return pieceInfos;
	}

	function SetDirtyArround(location, cargo) {
		if (cargoProductionInfos == null) { // cargoProductionInfosが使われていないケース
			return;
		}
		local pieceInfos = GetProductionInfos(cargo);
		foreach(index in GetArroundIndexes(location)) {
			local pieceInfo = pieceInfos[index];
			if (pieceInfo != null) {
				pieceInfo.dirty = true;
			}
		}
	}

	function SetDirty(location, cargo) {
		local pieceInfos = GetProductionInfos(cargo);
		local pieceInfo = pieceInfos[GetPieceIndex(location)];
		if (pieceInfo != null) {
			pieceInfo.dirty = true;
		}
	}

	function IsDirtyArround(location, cargo) {
		if (cargoProductionInfos == null) { // cargoProductionInfosが使われていないケース
			return false;
		}
		local pieceInfos = GetProductionInfos(cargo);
		foreach(index in GetArroundIndexes(location)) {
			local pieceInfo = pieceInfos[index];
			if (pieceInfo != null) {
				if (pieceInfo.dirty) {
					return true;
				}
			}
		}
		return false;
	}

	function GetArroundProductionCount(cargo, location) {
		local pieceInfos = GetProductionInfos(cargo);
		local sum = 0;
		local count = 0;
		local places = [];
		local pieceIndex = GetPieceIndex(location);
		foreach(index in GetArroundIndexes(location)) {
			local pieceInfo = pieceInfos[index];
			local arround = index != pieceIndex;
			if (pieceInfo != null && pieceInfo.usable) {
				local div = arround && pieceInfo.count >= 2 ? 2 : 1
				sum += pieceInfo.sum / div;
				count += pieceInfo.count / div;
				places.extend(pieceInfo.places);
			}
		}
		return [sum, count, places];
	}


	function GetArroundPlacesMaxDistance(cargo, location, distance) {
		local pieceInfos = GetProductionInfos(cargo);
		local result = [];
		foreach(index, include in GetArroundIndexInclude(location, distance)) {
			local pieceInfo = pieceInfos[index];
			if (pieceInfo != null) {
				if (include == 4) {
					result.extend(pieceInfo.places);
				} else {
					foreach(place in pieceInfo.places) {
						if (AIMap.DistanceManhattan(place.GetLocation(), location) <= distance) {
							result.push(place);
						}
					}
				}
			}
		}
		return result;
	}

	function GetCargoInfos(cargo, isProducing) {
		return isProducing ? GetProductionInfos(cargo) : GetAcceptInfos(cargo);
	}

	// largeIndexは4*4 piece単位
	function GetPlacesInLargeIndex(cargo, isProducing, largeIndex) {
		local result = [];
		local xIndex = (largeIndex % largePieceNumX) * 4;
		local yIndex = (largeIndex / largePieceNumX) * 4;
		local topLeftIndex = xIndex + yIndex * pieceNumX;
		local pieceInfos = GetCargoInfos(cargo, isProducing);
		for (local y = 0; y < 4; y++) {
			for (local x = 0; x < 4; x++) {
				local index = topLeftIndex + y * pieceNumX + x;
				if (index < pieceInfos.len()) {
					result.extend(pieceInfos[index].places);
				}
			}
		}
		return result;
	}

	function GetPlacesInIndexes(cargo, isProducing, indexes) {
		local pieceInfos = GetCargoInfos(cargo, isProducing);
		local result = [];
		foreach(index in indexes) {
			result.extend(pieceInfos[index].places);
		}
		return result;
	}

	function GetArroundPlaces(cargo, isProducing, location, minDistance, maxDistance) {
		local pieceInfos = GetCargoInfos(cargo, isProducing);
		local inner = minDistance >= 1 ? GetArroundIndexInclude(location, minDistance) : null;
		local outer = GetArroundIndexInclude(location, maxDistance);
		local result = [];
		foreach(index, include in outer) {
			local pieceInfo = pieceInfos[index];
			if (pieceInfo != null) {
				if (include == 4) {
					if (inner != null && inner.rawin(index)) {
						if (inner.rawget(index) != 4) {
							foreach(place in pieceInfo.places) {
								local distance = AIMap.DistanceManhattan(place.GetLocation(), location);
								if (minDistance <= distance && distance < maxDistance) {
									result.push(place);
								}
							}
						}
					} else {
						result.extend(pieceInfo.places);
					}
				} else {
					foreach(place in pieceInfo.places) {
						local distance = AIMap.DistanceManhattan(place.GetLocation(), location);
						if (minDistance <= distance && distance < maxDistance) {
							result.push(place);
						}
					}
				}
			}
		}
		return result;
	}

	function GetArroundIndexes(location) {
		local pieceIndex = GetPieceIndex(location);
		local x = pieceIndex % pieceNumX;
		local y = pieceIndex / pieceNumX;
		local indexes = [];
		indexes.push(pieceIndex);
		if (x >= 1) {
			indexes.push(pieceIndex - 1);
		}
		if (y >= 1) {
			indexes.push(pieceIndex - pieceNumX);
		}
		if (x < pieceNumX - 1) {
			indexes.push(pieceIndex + 1);
		}
		if (y < pieceNumY - 1) {
			indexes.push(pieceIndex + pieceNumX);
		}
		return indexes;
	}

	function GetArroundIndexInclude(location, distance) {
		local indexes = {};
		local checked = {};
		local queue = [];
		local AddQueue = function(cx, cy): (checked, queue) {
			if (cx >= 0 && cy >= 0 && cx < pieceNumX && cy < pieceNumY) {
				local i = cx + cy * pieceNumX;
				if (!checked.rawin(i)) {
					queue.push(i);
				}
			}
		};
		local center = GetPieceIndex(location);
		queue.push(center);
		indexes.rawset(center, 0);
		while (queue.len()) {
			local cur = queue.pop();
			checked.rawset(cur, cur);
			local count = 0;
			foreach(p in GetPieceRectangle(cur)) {
				if (AIMap.DistanceManhattan(p, location) <= distance) {
					count++;
				}
			}
			if (count == 0) continue;
			indexes.rawset(cur, count);
			local x = cur % pieceNumX;
			local y = cur / pieceNumX;
			AddQueue(x - 1, y);
			AddQueue(x + 1, y);
			AddQueue(x, y - 1);
			AddQueue(x, y + 1);
		}
		local x = AIMap.GetTileX(location);
		local y = AIMap.GetTileY(location);
		CheckEdgeXY(indexes, x - distance, y);
		CheckEdgeXY(indexes, x + distance, y);
		CheckEdgeXY(indexes, x, y + distance);
		CheckEdgeXY(indexes, x, y - distance);
		return indexes;
	}



	function GetPieceRectangle(index) {
		local x = index % pieceNumX;
		local y = index / pieceNumX;
		local result = [];
		result.push(AIMap.GetTileIndex(x * PIECE_SIZE, y * PIECE_SIZE));
		result.push(AIMap.GetTileIndex((x + 1) * PIECE_SIZE - 1, y * PIECE_SIZE));
		result.push(AIMap.GetTileIndex(x * PIECE_SIZE, (y + 1) * PIECE_SIZE - 1));
		result.push(AIMap.GetTileIndex((x + 1) * PIECE_SIZE - 1, (y + 1) * PIECE_SIZE - 1));
		return result;
	}

	function CheckEdgeXY(indexes, x, y) {
		local index = GetPieceIndex(HgTile.InMapXY(x, y).tile);
		if (!indexes.rawin(index)) {
			indexes.rawset(index, 1);
		}
	}

	function GetIndexesInSegment(segmentIndex, segmentNum) {
		if (pieceNumX * pieceNumY < segmentNum) {
			return null;
		}
		local samples = {};
		for (local i = 1; i <= 4; i++) {
			if (segmentNum % i == 0) {
				local w = segmentNum / i;
				local h = i;
				local nmin = min(w, h);
				local nmax = max(w, h);
				samples.rawset(nmin + "-" + nmax, [nmin, nmax]);
			}
		}
		local pieceNumMin = min(pieceNumX, pieceNumY);
		local pieceNumMax = max(pieceNumX, pieceNumY);
		local best = null;
		local maxMinPiece = -1;
		foreach(s, a in samples) {
			HgLog.Info("s:" + s + " pieceNumMin" + pieceNumMin + " a[0]" + a[0]);
			if (pieceNumMin % a[0] != 0) {
				continue;
			}
			local minPiece = min(pieceNumMin / a[0], pieceNumMax / a[1]);
			if (maxMinPiece < minPiece) {
				maxMinPiece = minPiece;
				best = a;
			}
		}
		if (best == null) {
			return null;
		}
		local pieceNum = pieceNumX * pieceNumY;
		local minSeg = best[0];
		local maxSeg = best[1];
		HgLog.Info("minSeg:" + minSeg + " maxSeg:" + maxSeg);
		local result = [];
		if (pieceNumY < pieceNumX) {
			local segNumX = maxSeg;
			local segNumY = minSeg;
			local segH = pieceNumY / segNumY;
			local segY = segmentIndex / segNumX;
			local segPieceNum = segH * pieceNumX / segNumX;
			local segPieceNumM = segH * pieceNumX % segNumX;
			local countPiece = 0;
			local countSeg = 0;
			local currentSegIndex = segY * segNumX;
			for (local x = 0; x < pieceNumX; x++) {
				for (local y = 0; y < segH; y++) {
					if (currentSegIndex == segmentIndex) {
						result.push((segY * segH + y) * pieceNumX + x);
					}
					countPiece++;
					if (countPiece == segPieceNum + (countSeg < segPieceNumM ? 1 : 0)) {
						if (currentSegIndex == segmentIndex) {
							return result;
						}
						countSeg++;
						currentSegIndex++;
						countPiece = 0;
					}
				}
			}
		} else {
			local segNumX = minSeg;
			local segNumY = maxSeg;
			local segW = pieceNumX / segNumX;
			local segX = segmentIndex % segNumX;
			local segPieceNum = segW * pieceNumY / segNumY
			local segPieceNumM = segW * pieceNumY % segNumY;
			local currentSegIndex = segX;
			local countPiece = 0;
			local countSeg = 0;
			for (local y = 0; y < pieceNumY; y++) {
				for (local x = 0; x < segW; x++) {
					if (currentSegIndex == segmentIndex) {
						result.push(y * pieceNumX + segX * segW + x);
					}
					countPiece++;
					if (countPiece == segPieceNum + (countSeg < segPieceNumM ? 1 : 0)) {
						if (currentSegIndex == segmentIndex) {
							return result;
						}
						currentSegIndex += segNumX;
						countSeg++;
						countPiece = 0;
					}
				}
			}
		}
		return result;
	}
}


class DistancePlaces {
	places = null;
	indexPlaces = null;

	constructor(places, orgTile) {
		this.indexPlaces = {};
		foreach(place in places) {
			local distanceSample = AIMap.DistanceManhattan(orgTile, place.GetLocation()) / 10;
			local distanceIndex = HogeAI.distanceSampleIndex[min(distanceSample, HogeAI.distanceSampleIndex.len() - 1)];
			local dplaces;
			if (indexPlaces.rawin(distanceIndex)) {
				dplaces = indexPlaces[distanceIndex];
			} else {
				dplaces = [];
				indexPlaces.rawset(distanceIndex, dplaces);
			}
			dplaces.push(place);
		}
	}

	function GetPlaces(distanceIndex) {
		return indexPlaces.rawin(distanceIndex) ? indexPlaces[distanceIndex] : [];
	}
}

class CargoDistancePlaces {
	cargo = null;
	isProducing = null;
	orgTile = null;

	indexPlaces = null;

	constructor(cargo, isProducing, orgTile) {
		this.cargo = cargo;
		this.isProducing = isProducing;
		this.orgTile = orgTile;
		this.indexPlaces = {};
	}

	function GetPlaces(distanceIndex) {
		if (!indexPlaces.rawin(distanceIndex)) {
			local range = HogeAI.GetEstimateRange(HogeAI.distanceEstimateSamples, distanceIndex);
			if (range[0] == null) range[0] = 0;
			if (range[1] == null) range[1] = HogeAI.distanceEstimateSamples[distanceIndex];
			indexPlaces.rawset(distanceIndex, PlaceProduction.Get().GetArroundPlaces(cargo, isProducing, orgTile, range[0], range[1]));
		}
		return indexPlaces[distanceIndex];
	}


}

class PlaceDictionary {
	static instance = GeneratorContainer(function() {
		return PlaceDictionary();
	});

	static function Get() {
		return PlaceDictionary.instance.Get();
	}

	sources = null;
	dests = null;
	nearWaters = null;

	constructor() {
		sources = {};
		dests = {};
		nearWaters = {};
	}

	function AddRoute(route) {
		local srcPlace = route.srcHgStation.place;
		local destPlace = route.destHgStation.place;

		if (srcPlace != null) {
			AddRouteTo(sources, srcPlace, route);
			HgLog.Info("AddRouteTo sources:" + srcPlace + " " + route);
		}
		if (destPlace != null) {
			if (route.IsBiDirectional()) {
				AddRouteTo(sources, destPlace.GetProducing(), route);
				HgLog.Info("AddRouteTo sources:" + destPlace.GetProducing() + " " + route);
			} else {
				AddRouteTo(dests, destPlace, route);
				HgLog.Info("AddRouteTo dests:" + destPlace + " " + route);
			}
		}
		route.srcHgStation.AddUsingRoute(route);
		route.destHgStation.AddUsingRoute(route);
	}

	function RemoveRoute(route) {
		if (route.srcHgStation.place != null) {
			RemoveRouteFrom(sources, route.srcHgStation.place, route);
		}
		if (route.destHgStation.place != null) {
			if (route.IsBiDirectional()) {
				RemoveRouteFrom(sources, route.destHgStation.place.GetProducing(), route);
			} else {
				RemoveRouteFrom(dests, route.destHgStation.place, route);
			}
		}
		route.srcHgStation.RemoveUsingRoute(route);
		route.destHgStation.RemoveUsingRoute(route);
	}


	function RemoveRouteFrom(dictionary, place, route) {
		local id = place.GetFacilityId();
		if (dictionary.rawin(id)) {
			ArrayUtils.Remove(dictionary[id], route);
		}
	}

	function AddRouteTo(dictionary, place, route) {
		local id = place.GetFacilityId();
		if (!dictionary.rawin(id)) {
			dictionary[id] <- [];
		}
		ArrayUtils.Add(dictionary[id], route);
	}

	function GetRoutes(dictionary, place) {
		local id = place.GetFacilityId();
		if (!dictionary.rawin(id)) {
			dictionary[id] <- [];
		}
		return dictionary[id];
		/*		local result = [];
				foreach(route in dictionary[id]) {
					if(!route.IsClosed()) {
						result.push(route);
					}
				}
				return result;*/
	}

	function CanUseAsSource(place, cargo) {
		return true;
	}

	function IsUsedAsSourceCargo(place, cargo) {
		foreach(route in GetRoutesBySource(place)) {
			if (route.HasCargo(cargo)) {
				return true;
			}
		}
		return false;
	}

	function GetUsedAsSourceByPriorityRoute(place, cargo) {
		local result = [];
		foreach(route in GetRoutesBySource(place)) {
			local vehicleType = route.GetVehicleType();
			if (((vehicleType == AIVehicle.VT_RAIL && !route.IsSingle()) || vehicleType == AIVehicle.VT_AIR) && route.HasCargo(cargo)) {
				result.push(route);
			}
		}
		return result;
	}


	function GetRoutesByDestCargo(place, cargo) {
		local result = [];
		foreach(route in GetRoutesByDest(place)) {
			if (route.HasCargo(cargo)) {
				result.push(route);
			}
		}
		return result;

	}

	function GetRoutesBySource(place) {
		local result = [];
		foreach(stationGroup, _ in place.GetStationGroups()) {
			result.extend(stationGroup.GetRoutesUsingSource());
		}
		return result;
		//		return GetRoutes(sources,place);
	}

	function GetRoutesByDest(place) {
		local result = [];
		foreach(stationGroup, _ in place.GetStationGroups()) {
			result.extend(stationGroup.GetRoutesUsingDest());
		}
		return result;
		//return GetRoutes(dests,place);
	}

}


class Place {

	static removedDestPlaceDate = [];
	static ngPathFindPairs = {};
	static productionHistory = [];
	static needUsedPlaceCargo = [];
	static ngPlaces = {};
	static ngCandidatePlaces = {};
	static placeStationDictionary = {};
	static canBuildAirportCache = {};
	static notUsedProducingPlaceCache = ExpirationTable(90);
	static cargoProducingCache = ExpirationTable(180);
	static cargoAcceptingCache = ExpirationTable(180);
	static producingPlaceDistanceListCache = ExpirationTable(90);
	static supportEstimatesCache = ExpirationTable(360);
	static usedOtherCompanyEstimationCache = ExpirationRawTable(180);
	static nearLandCache = {};
	static maybeNotUsed = {};
	static placeCache = {};
	static townDensity = {
		value = null
	};
	static averageTownPopulation = ExpirationTable(360);
	static placeCargoUsingRoutes = {};

	static function SaveStatics(data) {
		local array = [];

		array = [];
		foreach(placeDate in Place.removedDestPlaceDate) {
			local t = placeDate[0].Save();
			t.date <- placeDate[1];
			array.push(t);
		}
		data.removedDestPlaceDate <- array;

		array = [];
		foreach(t in Place.needUsedPlaceCargo) {
			array.push([t[0].Save(), t[1]]);
		}
		data.needUsedPlaceCargo <- array;

		data.ngPathFindPairs <- Place.ngPathFindPairs;
		data.placeStationDictionary <- Place.placeStationDictionary;
		data.industryClosedDate <- HgIndustry.industryClosedDate;

		PlaceProduction.Get().Save(data);

		data.nearWaters <- PlaceDictionary.Get().nearWaters;
		data.ngPlaces <- Place.ngPlaces;
		data.ngCandidatePlaces <- Place.ngCandidatePlaces;
		data.maybeNotUsed <- Place.maybeNotUsed;
		data.placeCargoUsingRoutes <- Place.placeCargoUsingRoutes;
	}


	static function LoadStatics(data) {

		foreach(t in data.removedDestPlaceDate) {
			Place.removedDestPlaceDate.push([Place.Load(t), t.date]);
		}
		foreach(t in data.needUsedPlaceCargo) {
			Place.needUsedPlaceCargo.push([Place.Load(t[0]), t[1]]);
		}
		foreach(k, v in data.ngPathFindPairs) {
			Place.ngPathFindPairs.rawset(k, v);
		}
		foreach(k, v in data.placeStationDictionary) {
			Place.placeStationDictionary[k] <- v;
		}
		foreach(k, v in data.industryClosedDate) {
			HgIndustry.industryClosedDate[k] <- v;
		}
		PlaceProduction.Get().Load(data);

		PlaceDictionary.Get().nearWaters = data.nearWaters;
		if (data.rawin("ngPlaces")) {
			HgTable.Extend(Place.ngPlaces, data.ngPlaces);
		}
		if (data.rawin("ngCandidatePlaces")) {
			HgTable.Extend(Place.ngCandidatePlaces, data.ngCandidatePlaces);
		}
		if (data.rawin("maybeNotUsed")) {
			HgTable.Extend(Place.maybeNotUsed, data.maybeNotUsed);
		}
		HgTable.Extend(Place.placeCargoUsingRoutes, data.placeCargoUsingRoutes);
	}

	static function Load(t) {
		switch (t.name) {
			case "StationGroup":
				return HgStation.stationGroups.rawget(t.id);
			case "HgIndustry":
				return HgIndustry(t.industry, t.isProducing, t.date);
			case "TownCargo":
				return TownCargo(t.town, t.cargo, t.isProducing);
			case "Coast":
				return CoastPlace(t.location);
		}
	}

	static function DumpData(data) {
		if (typeof data == "table" || typeof data == "array") {
			local result = "[";
			foreach(k, v in data) {
				result += (k + "=" + Place.DumpData(v)) + ",";
			}
			result += "]";
			return result;
		} else {
			return data;
		}

	}


	static function SetRemovedDestPlace(place) {
		Place.removedDestPlaceDate.push([place, AIDate.GetCurrentDate()]);
	}


	static function IsRemovedDestPlace(place) {
		local current = AIDate.GetCurrentDate();
		foreach(placeDate in Place.removedDestPlaceDate) {
			if (placeDate[0].IsSamePlace(place) && current < placeDate[1] + 60) {
				return true;
			}
		}
		return false;
	}

	static function AddNgPlace(facility, cargo, vehicleType, limit = null) {
		if (limit == null) {
			limit = AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES ? AIDate.GetCurrentDate() + 60 : AIDate.GetCurrentDate() + 1000;
		}
		Place.ngPlaces.rawset(facility.GetLocation() + ":" + cargo + ":" + vehicleType, limit);
		HgLog.Info("AddNgPlace:" + facility.GetName() + "[" + AICargo.GetName(cargo) + "] " + Route.Class(vehicleType).GetLabel() + " limit:" + DateUtils.ToString(limit));
	}

	static function RemoveNgPlace(facility, cargo, vehicleType) {
		if (Place.ngPlaces.rawdelete(facility.GetLocation() + ":" + cargo + ":" + vehicleType) != null) {
			HgLog.Info("RemoveNgPlace:" + facility.GetName() + "[" + AICargo.GetName(cargo) + "] vt:" + vehicleType);
		}
	}

	static function IsNgPlace(facility, cargo, vehicleType) {
		local key = facility.GetLocation() + ":" + cargo + ":" + vehicleType;
		if (Place.ngPlaces.rawin(key)) {
			local date = Place.ngPlaces[key];
			if (date == -1) {
				return true;
			} else {
				if (AIDate.GetCurrentDate() < date) {
					return true;
				}
			}
		}
		local checkOtherCompany = false;
		if (facility instanceof HgIndustry && AIIndustry.GetAmountOfStationsAround(facility.industry) >= 1) {
			if (HogeAI.Get().IsAvoidSecondaryIndustryStealing()) {
				if (facility.IsProcessing() && facility.GetRoutes().len() == 0) {
					local tileList = AITileList_IndustryAccepting(facility.industry, 5);
					tileList.Valuate(AITile.IsStationTile);
					tileList.RemoveValue(0);
					tileList.Valuate(AITile.GetOwner);
					tileList.RemoveValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
					if (tileList.Count() >= 1) {
						HgLog.Info("Detect SecondaryIndustryStealing:" + facility.GetName());
						foreach(vt in Route.allVehicleTypes) {
							Place.AddNgPlace(facility, cargo, vt, 10 * 365);
						}
						return true;
					}
				}

				/*
				if(AIIndustry.GetAmountOfStationsAround(facility.industry) >= 1 && facility.GetRoutes().len() == 0) { //TODO: これでは範囲内にある別施設用の自分のstationに反応してしまう
					HgLog.Info("Detect SecondaryIndustryStealing:"+facility.GetName());
					return true;
				}*/
			}
			if (Place.ExistsOtherHoge(facility)) {
				HgLog.Info("ExistsOtherHoge " + facility.GetName());
				foreach(vt in Route.allVehicleTypes) {
					Place.AddNgPlace(facility, cargo, vt, 10 * 365);
				}
				return true;
			}
		}

		return false;
	}


	static function ExistsOtherHoge(facility) {
		return false;
		/*		あんまり効果ない　if(facility instanceof HgIndustry && facility.GetRoutes().len() == 0) {
					if(AIIndustry.GetAmountOfStationsAround(facility.industry) >= 1) {
						local tileList = AITileList_IndustryAccepting(facility.industry,5);
						tileList.Valuate(AITile.IsStationTile);
						tileList.RemoveValue(0);
						tileList.Valuate(AITile.GetOwner);
						tileList.RemoveValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
						local companies = {};
						foreach(tile,company in tileList) {
							companies.rawset(company,0);
						}
						foreach(company,_ in companies) {
							local name = AICompany.GetName(company);
							if(name != null && name.find("AAAHogEx") != null) {
								return true;
							}
						}
					}
				}*/
		return false;
	}

	static function AddNgCandidatePlace(place, cargo, days = 365 * 3) {
		local limitDate = AIDate.GetCurrentDate() + days;
		Place.ngCandidatePlaces.rawset(place.GetLocation() + ":" + cargo, limitDate);
		HgLog.Info("AddNgCandidatePlace:" + place.GetName() + "[" + AICargo.GetName(cargo) + "] limit:" + DateUtils.ToString(limitDate));
	}

	static function IsNgCandidatePlace(place, cargo) {
		local key = place.GetLocation() + ":" + cargo;
		if (Place.ngCandidatePlaces.rawin(key)) {
			local date = Place.ngCandidatePlaces[key];
			if (date == -1) {
				return true;
			} else {
				return AIDate.GetCurrentDate() < date;
			}
		}
		return false;
	}

	static function AddNgPathFindPair(from, to, vehicleType, limitDay = null) {
		if (AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
			return;
		}
		local fromTile = typeof from == "integer" ? from : from.GetLocation();
		local toTile = typeof to == "integer" ? to : to.GetLocation();

		Place.ngPathFindPairs.rawset(fromTile + "-" + toTile + "-" + vehicleType, limitDay != null ? AIDate.GetCurrentDate() + limitDay : true);
	}

	static function IsNgPathFindPair(from, to, vehicleType) {
		local fromTile = typeof from == "integer" ? from : from.GetLocation();
		local toTile = typeof to == "integer" ? to : to.GetLocation();
		local key = fromTile + "-" + toTile + "-" + vehicleType;
		if (!Place.ngPathFindPairs.rawin(key)) {
			return false;
		}
		local limitDate = Place.ngPathFindPairs[key];
		if (limitDate == true) {
			return true;
		}
		local result = limitDate > AIDate.GetCurrentDate();
		if (!result) {
			Place.ngPathFindPairs.rawdelete(key);
		}
		return result;
	}

	static function AddNeedUsed(place, cargo) {
		Place.needUsedPlaceCargo.push([place, cargo]);
	}

	static function GetCargoPlaces(cargo, isProducing) {
		local result;
		if (isProducing) {
			if (Place.cargoProducingCache.rawin(cargo)) {
				return Place.cargoProducingCache.rawget(cargo);
			}
			result = Place.GetCargoProducing(cargo).array;
			Place.cargoProducingCache.rawset(cargo, result);
		} else {
			if (Place.cargoAcceptingCache.rawin(cargo)) {
				return Place.cargoAcceptingCache.rawget(cargo);
			}
			result = Place.GetCargoAccepting(cargo).array;
			Place.cargoAcceptingCache.rawset(cargo, result);
		}
		return result;

	}

	static function GetCargoProducing(cargo) {
		if (HogeAI.Get().IsFreightOnly() && CargoUtils.IsPaxOrMail(cargo)) {
			return HgArray([]);
		} else if (HogeAI.Get().IsPaxMailOnly() && !CargoUtils.IsPaxOrMail(cargo)) {
			return HgArray([]);
		}
		local result = [];
		foreach(industry, v in AIIndustryList_CargoProducing(cargo)) {
			local hgIndustry = HgIndustry(industry, true);
			result.push(hgIndustry);
		}
		if (Place.IsProducedByTown(cargo)) {
			local townList = AITownList();
			townList.Valuate(AITown.GetPopulation);
			townList.KeepAboveValue(200);
			foreach(town, v in townList) {
				result.push(TownCargo(town, cargo, true));
			}
		}
		return HgArray(result); //.Filter(function(p){ return p.GetName().find("Raston")!=null || p.GetName().find("Trinfingford")!=null; });
	}

	static function GetCargoAccepting(cargo) {
		local arr = [];
		if (Place.IsAcceptedByTown(cargo)) {
			local townList = AITownList();
			townList.Valuate(AITown.GetPopulation);
			local townEffect = AICargo.GetTownEffect(cargo);
			if (townEffect == AICargo.TE_GOODS) {
				townList.KeepAboveValue(1200);
			}
			foreach(town, population in townList) {
				local radius = TownCargo.GetRadiusPopulation(population);
				if (AITile.GetCargoAcceptance(AITown.GetLocation(town), cargo, 1, 1, radius) >= 8) {
					arr.push(TownCargo(town, cargo, false));
				}
			}
		}
		local result = HgArray(arr);
		result.array.extend(HgArray.AIListKey(AIIndustryList_CargoAccepting(cargo)).Map(function(a) {
			return HgIndustry(a, false);
		}).Filter(function(place): (cargo) {
			return place.IsCargoAccepted(cargo); //CAS_TEMP_REFUSEDを除外する
		}).array);
		return result; //.Filter(function(p){ return p.GetName().find("Raston")!=null || p.GetName().find("Trinfingford")!=null; });
	}

	static function IsAcceptedByTown(cargo) {
		return /*AIIndustryList_CargoAccepting(cargo).Count()==0 &&*/ AICargo.GetTownEffect(cargo) != AICargo.TE_NONE;
	}

	static function IsProducedByTown(cargo) {
		return CargoUtils.IsPaxOrMail(cargo); //TODO: 観光客とかは？
	}

	static function GetNotUsedProducingPlaces(cargo, limit = IntegerUtils.IntMax, indexes = null) {
		local placeDictionary = PlaceDictionary.Get();
		local places;
		if (indexes == null) {
			places = Place.GetCargoPlaces(cargo, true);
		} else {
			places = PlaceProduction.Get().GetPlacesInIndexes(cargo, true, indexes);
		}
		local result = [];
		if (places.len() > limit) {
			local list = AIList();
			list.Sort(AIList.SORT_BY_VALUE, false);
			foreach(index, place in places) {
				list.AddItem(index, place.GetLastMonthProduction(cargo));
			}
			foreach(index, _ in list) {
				local place = places[index];
				if (!placeDictionary.CanUseAsSource(place, cargo)) {
					continue;
				}
				if (Place.IsNgCandidatePlace(place, cargo)) {
					continue;
				}
				result.push(place);
				if (result.len() == limit) {
					return result;
				}
			}
		} else {
			foreach(place in places) {
				if (!placeDictionary.CanUseAsSource(place, cargo)) {
					continue;
				}
				if (Place.IsNgCandidatePlace(place, cargo)) {
					continue;
				}
				result.push(place);
			}
		}
		return result;
	}

	static function GetPlaces(cargo, fromTile, maxDistance) {
		local places = Place.GetCargoPlaces(cargo, true);
		if (places.len() >= 1000 && AIMap.GetMapSizeX() * AIMap.GetMapSizeY() >= 2048 * 2048) {
			local result = PlaceProduction.Get().GetArroundPlacesMaxDistance(cargo, fromTile, maxDistance);
			return result;
		}
		local result = [];
		foreach(place in places) {
			if (AIMap.DistanceManhattan(place.GetLocation(), fromTile) <= maxDistance) {
				result.push(place);
			}
		}
		return result;
	}

	static function SearchSrcAdditionalPlaces(srcStation, destTile, cargo, minDistance = 20, maxDistance = 200, minProduction = 60, vehicleType = AIVehicle.VT_RAIL) {
		if (srcStation.stationGroup == null) {
			return [];
		}
		local middlePlaceLocation = srcStation.place == null ? null : srcStation.place.GetLocation();
		local middleTile = srcStation.GetLocation();
		local a = [];
		foreach(place in Place.GetPlaces(cargo, middleTile, maxDistance)) {
			local t = {};
			local location = place.GetLocation();
			t.place <- place;
			t.location <- place.GetLocation();
			t.distance <- AIMap.DistanceManhattan(middleTile, t.location); // placesList[1].GetValue(index);
			if (t.distance > minDistance &&
				t.location != middlePlaceLocation &&
				!Place.IsNgPathFindPair(t.place, middleTile, vehicleType) &&
				PlaceDictionary.Get().CanUseAsSource(t.place, cargo)) {
				t.totalDistance <- destTile == null ? t.distance : AIMap.DistanceManhattan(destTile, t.location);
				a.push(t);
			}
		}
		return a;
	}

	static function SearchAdditionalAcceptingPlaces(cargos, srcTiles, lastAcceptingTile, maxDistance, minPopulation, vehicleType = AIVehicle.VT_RAIL) {

		local hgArray = null;
		local srcTilesScores = [];
		foreach(tile in srcTiles) {
			srcTilesScores.push([tile, HgTile(lastAcceptingTile).DistanceManhattan(HgTile(tile))]);
		}
		local places = PlaceProduction.Get().GetArroundPlaces(cargos[0], false, lastAcceptingTile, 0, maxDistance);
		hgArray = HgArray(places).Filter(function(place): (cargos, minPopulation) {
			if (place instanceof TownCargo) {
				if (minPopulation != null) {
					return AITown.GetPopulation(place.town) >= minPopulation;
				}
			}
			return true;
		}).Map(function(place): (lastAcceptingTile, srcTilesScores) {
			local t = {};
			t.place <- place;
			t.distance <- AIMap.DistanceManhattan(place.GetLocation(), lastAcceptingTile);
			if (t.distance > 0) {
				local score = 0;
				foreach(tileCurrentScore in srcTilesScores) {
					score += (t.place.DistanceManhattan(tileCurrentScore[0]) - tileCurrentScore[1]); // * 10000 / t.cost;
				}
				t.score <- score * 100 / srcTilesScores.len() / t.distance; //新規線路100マスあたりcargo距離が何マス伸びるのか
			} else {
				t.score <- 0;
			}
			return t;
		}).Filter(function(t): (lastAcceptingTile, vehicleType) {
			return 100 <= t.distance && 30 < t.score && !Place.IsNgPathFindPair(t.place, lastAcceptingTile, vehicleType);
		}).Map(function(t) {
			return [t.place, t.score /*Place.AdjustAcceptingPlaceScore(t.score,t.place,t.cargo)*/ ];
		});
		return hgArray.Sort(function(a, b) {
			return b[1] - a[1];
		}).array;

	}

	static function GetTownDensity() {
		if (Place.townDensity.value == null) {
			Place.townDensity.value = AITownList().Count().tofloat() / (AIMap.GetMapSizeX() * AIMap.GetMapSizeY());
		}
		return Place.townDensity.value;
	}

	static function GetAverageTownPopulation() {
		if (Place.averageTownPopulation.rawin("num")) {
			return Place.averageTownPopulation.rawget("num");
		}
		local list = AITownList();
		list.Valuate(AITown.GetPopulation);
		local total = 0;
		foreach(town, population in list) {
			total += population;
		}
		local result = total / list.Count();
		Place.averageTownPopulation.rawset("num", result);
		return result;
	}

	// TODO: industry以外のplaceが無効化した時にもcacheを消さないと誤動作するかも？idが再利用されるなら。
	static function DeletePlaceChaceIndustry(industryId) {
		Place.placeCache.rawdelete("Industry:" + industryId + ":true");
		Place.placeCache.rawdelete("Industry:" + industryId + ":false");
	}

	cache = null;

	function GetGId() {
		return Id();
	}

	function GetPlaceCache() {
		if (cache != null) return cache;
		local id = Id();
		if (Place.placeCache.rawin(id)) {
			return cache = Place.placeCache.rawget(id);
		}
		cache = {
			expectedProduction = ExpirationTable(30)
			currentExpectedProduction = ExpirationTable(30)
			sourceStationGroups = {}
			stationGroups = null
		}
		Place.placeCache.rawset(id, cache);
		return cache;
	}

	function DistanceManhattan(tile) {
		return HgTile(GetLocation()).DistanceManhattan(HgTile(tile));
	}

	function GetCargoMap() {
		local cache = GetPlaceCache();
		if ("cargoMap" in cache) return cache.cargoMap;

		local cargoMap = {};
		foreach(cargo in GetCargos()) {
			cargoMap.rawset(cargo, cargo);
		}
		cache.cargoMap <- cargoMap;
		return cargoMap;
	}

	function IsTreatCargo(cargo) {
		return GetCargoMap().rawin(cargo);
	}

	function IsAcceptingAndProducing(cargo) {
		return GetAccepting().IsTreatCargo(cargo) && GetProducing().IsTreatCargo(cargo);
	}

	function IsAcceptingCargo(cargo) {
		return GetAccepting().IsTreatCargo(cargo);
	}

	function IsProducingCargo(cargo) {
		return GetProducing().IsTreatCargo(cargo);
	}

	function GetProducingCargos() {
		return GetProducing().GetCargos();
	}

	function IsIncreaseByInput() {
		return !(this instanceof TownCargo) && IsIncreasable();
	}

	function CanUseNewRoute(cargo, vehicleType) {
		/*if(this instanceof TownCargo) {
			return true;
		}*/
		//HgLog.Warning( "canUsePlaceOnWater:"+HogeAI.Get().canUsePlaceOnWater+" "+this.IsBuiltOnWater()+" "+this.IsNearLand(cargo) );
		if (!HogeAI.Get().canUsePlaceOnWater && this.IsBuiltOnWater() && !this.IsNearLand(cargo)) {
			return false;
		}
		if (vehicleType == AIVehicle.VT_AIR) {
			return true;
		}
		if (HogeAI.Get().firs && CargoUtils.IsSupplyCargo(cargo)) { // supply cargo
			if (vehicleType == AIVehicle.VT_WATER) {
				local availableVts = Route.GetAvailableVehicleTypes();
				if (availableVts.rawin(AIVehicle.VT_ROAD) || availableVts.rawin(AIVehicle.VT_AIR)) {
					return false; // 船は容量がでかすぎる
				}
			}
			if (GetLastMonthProduction(cargo) / 26 < GetRoutesUsingSource(cargo).len()) {
				return false;
			}
			return true;
		}
		foreach(route in GetRoutesUsingSource(cargo)) {
			// 既存ルートの収益性を落とす分が計算されていない
			/*if(vehicleType != AIVehicle.VT_ROAD
					&& (route.GetVehicleType() == AIVehicle.VT_ROAD || route.IsSingle())) {
				continue;
			}*/
			if (route.IsOverflowPlace(this, cargo)) {
				continue;
			}
			//HgLog.Warning("GetRoutesUsingSource "+route);
			return false;
		}
		if (Place.IsRemovedDestPlace(this)) {
			//HgLog.Warning("IsRemovedDestPlace");
			return false;
		}
		return true;
	}

	function GetUsingRoutes(cargo = null) {
		return GetRoutes(cargo);
	}

	function GetRoutes(cargo = null) {
		local result = [];
		result.extend(GetProducing().GetRoutesUsingSource(cargo));
		result.extend(GetAccepting().GetRoutesUsingDest(cargo));
		return result;
	}


	function GetSourceStationGroups(cargo = null) {
		local cache = GetPlaceCache();
		if (cache.sourceStationGroups.rawin(cargo)) {
			return cache.sourceStationGroups.rawget(cargo);
		}
		local result = _GetSourceStationGroups(cargo);
		cache.sourceStationGroups.rawset(cargo, result);
		return result;
	}

	function _GetSourceStationGroups(cargo = null) {
		local table = {};
		foreach(route in GetRoutesUsingSource(cargo)) {
			if (route.IsTownTransferRoute()) {
				continue;
			}
			if (route.IsBiDirectional() && route.destHgStation.place != null && route.destHgStation.place.IsSamePlace(this)) {
				table.rawset(route.destHgStation.stationGroup, 0);
			} else if (route.srcHgStation.stationGroup != null) {
				table.rawset(route.srcHgStation.stationGroup, 0);
			}
		}
		return HgTable(table).Keys();
	}

	function GetRoutesUsingDest(cargo = null) {
		if (cargo == null) {
			return PlaceDictionary.Get().GetRoutesByDest(GetAccepting());
		}

		local result = []
		foreach(route in PlaceDictionary.Get().GetRoutesByDest(GetAccepting())) {
			if (route.HasCargo(cargo)) {
				result.push(route);
			}
		}
		return result;
	}

	function CanUseTrainSource() {
		return true;
		/*		if(this instanceof TownCargo) {
					return true;
				} else {
					return IsIncreasable();
				}*/
	}

	function GetUsedOtherCompanyEstimation() {
		if (!(this instanceof HgIndustry)) {
			return 0;
		}
		if (AIIndustry.GetAmountOfStationsAround(industry) >= 1) {
			return 1;
			/* 重いし不正確
			local tileList = AITileList_IndustryAccepting(industry,5);
			tileList.Valuate(AITile.IsStationTile);
			tileList.RemoveValue(0);
			tileList.Valuate(AITile.GetOwner);
			tileList.RemoveValue(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			local owners = {};
			foreach(tile,owner in tileList) {
				owners.rawset(owner,0);
			}
			//HgLog.Warning("_GetUsedOtherCompanyEstimation:"+owners.len()+" "+GetName());
			return owners.len();*/
		}
		return 0;
	}

	function IsCargoNotAcceptedRecently(cargo) {
		if (!IsCargoAccepted(cargo)) {
			return false;
		}
		foreach(route in PlaceDictionary.Get().GetRoutesByDestCargo(this, cargo)) {
			if (route.lastDestClosedDate != null && route.lastDestClosedDate > AIDate.GetCurrentDate() - 365) {
				return;
			}
		}
		return false;
	}

	function AddStation(station) {
		local facilityId = GetFacilityId();
		if (!Place.placeStationDictionary.rawin(facilityId)) {
			Place.placeStationDictionary[facilityId] <- [station.id];
		} else {
			Place.placeStationDictionary[facilityId].push(station.id);
		}
		local cache = GetPlaceCache();
		cache.sourceStationGroups.clear();
		cache.stationGroups = null;
	}

	function RemoveStation(station) {
		local facilityId = GetFacilityId();
		if (Place.placeStationDictionary.rawin(facilityId)) {
			ArrayUtils.Remove(Place.placeStationDictionary[facilityId], station.id);
		}
		local cache = GetPlaceCache();
		cache.sourceStationGroups.clear();
		cache.stationGroups = null;
	}

	function GetStations() {
		local result = [];
		local facilityId = GetFacilityId();
		if (Place.placeStationDictionary.rawin(facilityId)) {
			foreach(id in Place.placeStationDictionary[facilityId]) {
				if (!HgStation.worldInstances.rawin(id)) {
					HgLog.Warning("HgStation.worldInstances not found(GetStations).id:" + id);
					continue;
				}
				result.push(HgStation.worldInstances[id]);
			}
			return result;
		} else {
			return [];
		}
	}

	function HasStation(station) {
		local facilityId = GetFacilityId();
		if (Place.placeStationDictionary.rawin(facilityId)) {
			foreach(id in Place.placeStationDictionary[facilityId]) {
				if (id == station.id) {
					return true;
				}
			}
		}
		return false;
	}

	function GetStationGroups() {
		local cache = GetPlaceCache();
		if (cache.stationGroups == null) {
			cache.stationGroups = _GetStationGroups();
		}
		return cache.stationGroups;
	}

	function _GetStationGroups() {
		local result = {};
		foreach(hgStation in GetStations()) {
			result[hgStation.stationGroup] <- hgStation.stationGroup;
		}
		return result;
	}

	function AddUsingRouteAsSource(cargo, route) {
		local key = GetFacilityId() + "-" + cargo;
		local usingRoutes = null;
		if (Place.placeCargoUsingRoutes.rawin(key)) {
			usingRoutes = Place.placeCargoUsingRoutes.rawget(key);
		} else {
			usingRoutes = {};
			Place.placeCargoUsingRoutes.rawset(key, usingRoutes);
		}
		usingRoutes.rawset(route.id, route.id);
	}

	function RemoveUsingRouteAsSource(cargo, route) {
		local key = GetFacilityId() + "-" + cargo;
		if (Place.placeCargoUsingRoutes.rawin(key)) {
			Place.placeCargoUsingRoutes.rawget(key).rawdelete(route.id);
		}
	}

	function GetRoutesUsingSource(cargo = null) {
		if (cargo == null) {
			local result = [];
			foreach(producingCargo in GetProducing().GetCargos()) {
				result.extend(GetRoutesUsingSource(producingCargo));
			}
			return result;
		}
		local key = GetFacilityId() + "-" + cargo;
		local usingRoutes = null;
		if (Place.placeCargoUsingRoutes.rawin(key)) {
			usingRoutes = Place.placeCargoUsingRoutes.rawget(key);
			local result = [];
			foreach(routeId, _ in usingRoutes) {
				if (Route.allRoutes.rawin(routeId)) { // removeされるといなくなる
					result.push(Route.allRoutes[routeId]);
				}
			}
			return result;
		} else {
			return [];
		}
	}
	/*

		function GetRoutesUsingSource(cargo = null) {
			if(cargo == null) {
				return PlaceDictionary.Get().GetRoutesBySource(GetProducing());
			}

			local result = []
			foreach(route in PlaceDictionary.Get().GetRoutesBySource(GetProducing())) {
				if(route.IsDeliveringCargo(cargo)) {
					result.push(route);
				}
			}
			return result;
		}*/

	function GetRouteCountUsingSource(cargo = null) {
		local result = 0;
		foreach(route in GetRoutesUsingSource(cargo)) {
			if (!route.IsTownTransferRoute() /* && !route.IsOverflowPlace(this,cargo)*/ ) {
				result++;
			}
		}
		return result;
	}

	function GetLastMonthTransportedPercentage(cargo) {
		return 0; // オーバーライドして使う
	}

	function GetFutureExpectedProduction(cargo, vehicleType, isMine = false) {
		local rate = 100;
		if ((CargoUtils.IsPaxOrMail(cargo) || (!HogeAI.Get().ecs && !HogeAI.Get().firs)) && IsIncreasable()) {
			rate = 150;
		}
		return GetExpectedProduction(cargo, vehicleType, isMine) * rate / 100;

		/*
		if(HogeAI.Get().buildingTimeBase && !HogeAI.Get().ecs) {
			if(IsIncreasable() && vehicleType == AIVehicle.VT_RAIL) {
				return GetExpectedProduction(cargo,vehicleType,isMine) * 3; // 将来は今よりずっと増える
			}
		}
		return GetExpectedProduction(cargo,vehicleType,isMine);*/
	}

	function GetExpectedProduction(cargo, vehicleType, isMine = false, isMin = false) {
		local cache = GetPlaceCache();
		local key = cargo + "-" + vehicleType + "-" + isMine + "-" + isMin;
		if (cache.expectedProduction.rawin(key)) {
			return cache.expectedProduction.rawget(key);
		}
		local result = _GetExpectedProduction(cargo, vehicleType, isMine, isMin);
		cache.expectedProduction.rawset(key, result);
		return result;
	}

	function _GetExpectedProduction(cargo, vehicleType, isMine = false, isMin = false) {
		return GetExpectedProductionAll(cargo, vehicleType, isMine, isMin);
	}

	function GetCurrentExpectedProduction(cargo, vehicleType, isMine = false, callers = null) {
		local cache = GetPlaceCache();
		local key = cargo + "-" + vehicleType + "-" + isMine;
		if (cache.currentExpectedProduction.rawin(key)) {
			return cache.currentExpectedProduction.rawget(key);
		}
		local result = _GetCurrentExpectedProduction(cargo, vehicleType, isMine, callers); // override
		cache.currentExpectedProduction.rawset(key, result);
		return result;
	}

	function GetProductionArroundCount(cargo, vehicleType) {
		if (!HogeAI.Get().roiBase && !HogeAI.Get().ecs && IsProcessing() &&
			(vehicleType == AIVehicle.VT_RAIL || vehicleType == AIVehicle.VT_WATER)) {
			local result = 0;
			local placeProduction = PlaceProduction.Get();
			foreach(acceptingCargo in GetAccepting().GetCargos()) {
				result += placeProduction.GetArroundProductionCount(acceptingCargo, GetLocation())[1];
			}
			return result;
		}
		return 0;
	}

	function GetSupportEstimate(isMin = false) {
		local key = Id() + "-" + isMin;
		if (Place.supportEstimatesCache.rawin(key)) {
			return Place.supportEstimatesCache.rawget(key);
		}
		local result = _GetSupportEstimate(isMin)
		Place.supportEstimatesCache.rawset(key, result);
		return result;
	}

	function _GetSupportEstimateMin() {
		local vehicleTypes = Route.GetAvailableVehicleTypes();
		local notToMeet = GetNotToMeetCargos();
		local minBuildingTime = IntegerUtils.IntMax;
		local minEstimate = null;
		foreach(acceptingCargo, _ in notToMeet) {
			local productionCount = placeProduction.GetArroundProductionCount(acceptingCargo, GetLocation());
			local minLocation = Integer.IntMax;
			local minPlace = null;
			local location = GetLocation();
			foreach(place in productionCount[2]) {
				local distance = AIMap.DistanceManhattan(place.GetLocation(), location);
				if (distance < minDistance) {
					minDistance = distance;
					minPlace = place;
				}
			}
			if (minPlace == null) continue;
			foreach(vehicleType, _ in vehicleTypes) {
				local estimate = Route.Estimate(vehicleType, acceptingCargo, minDistance, minPlace.GetCurrentExpectedProduction(acceptCargo, vehicleType), false);
				if (minBuildingTime < estimate.buildingTime) {
					minBuildingTime = estimate.buildingTime;
					minEstimate = estimate;
				}
			}
		}
		return {
			routeIncome = minEstimate == null ? 0 : minEstimate.routeIncome
			buildingTime = minEstimate == null ? 0 : minEstimate.buildingTime
			production = minEstimate.production
		}
	}

	function _GetSupportEstimate(isMin) {
		if (!IsIncreaseByInput()) {
			return {
				production = 0
			};
		}
		if (isMin) {
			return _GetSupportEstimateMin();
		}
		local routeIncome = {};
		local buildingTime = {};
		local production = 0;
		local count = 0;
		local connectedPlaces = {};
		local vehicleTypes = Route.GetAvailableVehicleTypes();
		foreach(vehicleType, _ in vehicleTypes) {
			routeIncome[vehicleType] <- 0;
			buildingTime[vehicleType] <- 0;
		}
		local maxProd = 1000000;
		if (HogeAI.Get().firs) {
			if (!IsProcessing) {
				if (IsMeetExceptProcessing()) {
					return {
						production = 0
					};
				}
				if (IsRaw()) {
					maxProd = 80 / 3;
				} else {
					maxProd = 640 / 3;
				}
			}
		}
		foreach(acceptingCargo in GetAccepting().GetCargos()) {
			//HgLog.Warning("acceptingCargo:"+AICargo.GetName(acceptingCargo)+" "+this);
			local productionCount = PlaceProduction.Get().GetArroundProductionCount(acceptingCargo, GetLocation());
			if (productionCount[0] == 0 || productionCount[1] == 0) {
				continue;
			}
			local avgProd = productionCount[0] / productionCount[1];
			if (avgProd == 0) {
				continue;
			}
			local srcNum = min(productionCount[1], (maxProd + avgProd - 1) / avgProd);
			foreach(vehicleType, _ in vehicleTypes) {
				local estimate = Route.Estimate(vehicleType, acceptingCargo,
					PlaceProduction.PIECE_SIZE,
					avgProd,
					false);
				if (estimate == null) {
					continue;
				}
				local connected = false; // 同一placeで複数cargo
				//HgLog.Warning("GetVehicleType:"+estimate.GetVehicleType()+" "+this);
				if (vehicleType == AIVehicle.VT_RAIL) {
					foreach(p in productionCount[2]) {
						local placeId = p.Id();
						if (connectedPlaces.rawin(placeId)) {
							connected = true;
							//HgLog.Warning("conncted:"+AICargo.GetName(acceptingCargo)+" "+this);
						} else {
							connectedPlaces.rawset(placeId, 0);
							//HgLog.Warning("connct:"+p+" "+AICargo.GetName(acceptingCargo)+" "+this);
						}
					}
				}
				routeIncome[vehicleType] += estimate.routeIncome * srcNum;
				if (!connected) {
					buildingTime[vehicleType] += estimate.buildingTime * srcNum;
					/*if(productionCount[1] >= 10) { // 密度が上がると効率的になる
						buildingTime[vehicleType] += estimate.buildingTime * (9 + (productionCount[1]-9)/2);
					} else {
						buildingTime[vehicleType] += estimate.buildingTime * productionCount[1];
					}*/
				}
				/*
				HgLog.Warning("GetSupportEstimate"
					+" cargo:"+AICargo.GetName(acceptingCargo)
					+" vehicleType:"+vehicleType
					+" routeIncome:"+estimate.routeIncome
					+" buildingTime:"+estimate.buildingTime
					+(estimate.rawin("infraBuildingTime")?(" infraBT:"+estimate.infraBuildingTime):"")
					+" production:"+(productionCount[0] / productionCount[1])
					+" count:"+productionCount[1]
					+" connected:"+connected
					+" "+this);*/
			}
			production += avgProd * srcNum * 2 / 3;
			count += srcNum;
		}
		local maxVehicleType = null;
		local maxValue = null;
		foreach(vehicleType, _ in vehicleTypes) {
			if (buildingTime[vehicleType] != 0) {
				local value = routeIncome[vehicleType] / buildingTime[vehicleType];
				if (maxValue == null || maxValue < value) {
					maxValue = value;
					maxVehicleType = vehicleType;
				}
			}
		}
		/*
		HgLog.Warning("GetSupportEstimate maxVehicleType:"+maxVehicleType
			+" routeIncome:"+(maxVehicleType==null ? 0 : routeIncome[maxVehicleType])
			+" buildingTime:"+(maxVehicleType==null ? 0 : buildingTime[maxVehicleType])
			+" production:"+production
			+" count:"+count
			+" "+this);*/
		return {
			routeIncome = maxVehicleType == null ? 0 : routeIncome[maxVehicleType]
			buildingTime = maxVehicleType == null ? 0 : buildingTime[maxVehicleType]
			production = production
		}
	}

	function GetExpectedProductionAll(cargo, vehicleType, isMine = false, isMin = false) {
		return AdjustUsing(_GetExpectedProductionAll(cargo, vehicleType, isMin), cargo, isMine);
	}

	function _GetExpectedProductionAll(cargo, vehicleType, isMin) {
		local production = GetLastMonthProduction(cargo);
		if (!IsIncreasable()) {
			return production;
		}
		local placeProduction = PlaceProduction.Get();
		if (!HogeAI.Get().ecs && !HogeAI.Get().firs) {
			if (HogeAI.Get().buildingTimeBase && IsProcessing()) { //support routeの見積もりはbuildingTimeBaseのみ
				//				production += GetSupportRouteEstimate(1000).production * 2 / 3;

				local inputableProduction = 0;
				foreach(acceptingCargo in GetAccepting().GetCargos()) {
					if (CargoUtils.IsDelivable(acceptingCargo)) {
						inputableProduction += placeProduction.GetArroundProductionCount(acceptingCargo, GetLocation())[0];
					}
				}
				production += inputableProduction * 2 / 3;
			}
		}
		if (HogeAI.Get().firs && !HogeAI.Get().roiBase) {
			/*if(!preEstimate) {
				if(IsRaw()) {
					// 満たされていない場合、満たしたら3倍になる
					if(GetToMeetCargos().len() == 0) {
						if(GetSupportRouteEstimate(80).production >= 80) {
							production *= 3;
						}
					}
				} else if(IsProcessing()) {
					// 入力量 × 満たしたカーゴ種 / 受け入れカーゴ種 (cargo毎に係数があるが、不明なので1)
					local supportRouteInfo = GetSupportRouteCandidates();
					local inputableProduction = GetSupportRouteEstimate(1000).production * 2 / 3;
					local notToMeetGargos = HgArray(GetNotToMeetCargos()).ToTable();
					local newMeetable = 0;
					local cargos = GetAccepting().GetCargos();
					local supportCargos = supportRouteInfo.supportCargos;
					foreach(acceptingCargo in cargos) {
						if(notToMeetGargos.rawin(acceptingCargo) && supportCargos.rawin(acceptingCargo)) {
							newMeetable ++;
						}
					}
					local meetable = newMeetable + (cargos.len() - notToMeetGargos.len());
					production += production * newMeetable / cargos.len() + inputableProduction * meetable / cargos.len();
				} else { // Wharf
					// 一定以上入力していたら2倍
					if(GetToMeetCargos().len() == 0) {
						local exists = false;
						if(GetSupportRouteEstimate(160).production >= 160) {
							if(exists) production *= 2;
						}
					}
				}
			} else {*/
			local lastMonth = production;
			local inputableProduction = 0;
			local newAvailable = 0;
			local acceptingCargos = GetAccepting().GetCargos();
			local notToMeet = GetNotToMeetCargos();
			foreach(acceptingCargo in acceptingCargos) {
				local availableProductionCount = placeProduction.GetArroundProductionCount(acceptingCargo, GetLocation());
				if (notToMeet.rawin(acceptingCargo) && availableProductionCount[0] >= 1) {
					newAvailable++;
					if (isMin) {
						inputableProduction += availableProductionCount[0] / availableProductionCount[1];
						break;
					}
				}
				if (!isMin) {
					inputableProduction += availableProductionCount[0];
				}
			}
			if (IsRaw()) {
				if (inputableProduction >= 50 && notToMeet.len() >= 1) {
					production *= 3;
				}
			} else if (IsProcessing()) {
				local meets = acceptingCargos.len() - notToMeet.len();
				if (meets >= 1) {
					production = production / meets * (meets + newAvailable);
				}
				local newProd = inputableProduction / acceptingCargos.len() * (meets + newAvailable);
				production += newProd * GetProducingRate(cargo) / 100 * 2 / 3;
			} else {
				if (inputableProduction >= 150 && (acceptingCargos.len() - notToMeet.len()) == 0) {
					production *= 3;
				}
			}
			//HgLog.Info("_GetExpectedProductionAll:" + this+ "["+AICargo.GetName(cargo)+"]:"+production + " lastMonth:"+lastMonth
			//	+" inputableProduction:"+inputableProduction+" newAvailable:"+newAvailable+" notToMeet:"+notToMeet.len());


			/*

			if(IsProcessing()) {
				if(allCargosAvailable) {
					if(GetNotToMeetCargos().len() >= 1) {
						production *= 3;
					}
					production += inputableProduction / 4;
				} else {
					production += inputableProduction / 4 / 3;
				}
			} else if(acceptingCargos.len() >= 1) {
				if(allCargosAvailable && inputableProduction >= 1 && GetNotToMeetCargos().len() >= 1) {
					production *= 3;
				}
			}*/
			//}
		}
		if (HogeAI.Get().ecs /*GetUsableMoney() >= HogeAI.Get().GetInflatedMoney(2000000)*/ && IsRaw() && production >= 1) {
			// 4d656f9f 00:coal mine 300 / 02:sand pit 900
			// 4d656f9c 08:oil well 750 / 09:oil rig 375
			// 4d656f94 0d:iron ore 150 / 18:bauxite 150
			// 4d656f95 12:forest 192
			// 4d656f97 1e:farm 168(cereals) 264(fibre crops)  / 22:fruit plantation    / 1d:fishing grounds 350
			local cargoLabel = AICargo.GetCargoLabel(cargo);
			local industryTraits = GetIndustryTraits();
			local industryType = AIIndustry.GetIndustryType(this.industry);
			local ecsRaw = true;
			if (industryTraits == "COAL,/VEHI," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f9f, 0x00)*/ ) {
				production = max(300, production);
			} else if (industryTraits == "SAND,/VEHI,") {
				production = max(900, production);
			} else if (industryTraits == "OIL_,/" /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f9c, 0x08)*/ ) {
				production = max(750, production);
			} else if (industryTraits == "OIL_,PASS,/PASS," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f9c, 0x09)*/ ) {
				if (cargoLabel == "OIL_") {
					production = max(375, production);
				}
			} else if (industryTraits == "IORE,/VEHI," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f94, 0x0d)*/ ) {
				production = max(150, production);
			} else if (industryTraits == "AORE,/VEHI," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f94, 0x18)*/ ) {
				production = max(150, production);
			} else if (industryTraits == "WOOD,/VEHI," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f95, 0x12)*/ ) {
				production = max(192, production);
			} else if (industryTraits == "FICR,CERE,/VEHI,FERT," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f97, 0x1e))*/ ) {
				if (cargoLabel == "CERE") {
					production = max(168, production);
				} else if (cargoLabel == "FICR") {
					production = max(264, production);
				}
			} else if (industryTraits == "FISH,PASS,/PASS," /*industryType == AIIndustryType.ResolveNewGRFID(0x4d656f97, 0x1d)*/ ) {
				if (cargoLabel == "FISH") {
					production = max(350, production);
				}
			} else {
				ecsRaw = false;
			}
			if (ecsRaw) {
				/*スピードでの調整
								if(vehicleType == AIVehicle.VT_RAIL) {
									production *= 2;
								}
								if(vehicleType == AIVehicle.VT_ROAD)  {
									production /= 2;
								}*/
				if (HogeAI.Get().roiBase) {
					production /= 3;
				}
			}
		}




		return production;
	}

	function AdjustUsing(production, cargo, isMine) {
		local key = Id() + "-" + cargo;
		local stationGroups = GetSourceStationGroups(cargo);
		if (stationGroups.len() == 0 && (!Place.maybeNotUsed.rawin(key) || Place.maybeNotUsed[key])) {
			if (GetLastMonthTransportedPercentage(cargo) >= 1) {
				Place.maybeNotUsed.rawset(key, false);
			} else {
				Place.maybeNotUsed.rawset(key, true);
			}
		}
		local otherCompanies = !Place.maybeNotUsed.rawin(key) || Place.maybeNotUsed.rawin(key) ? 0 : 1;
		//local usingRoutes = GetRoutesUsingSource(cargo);
		local totalRates = 0;
		local count = 0;
		foreach(stationGroup in stationGroups) {
			local stationId = stationGroup.GetAIStation();
			if (stationId == null) continue;
			totalRates += AIStation.GetCargoRating(stationId, cargo);
			count++;
		}
		local isTownCargo = this instanceof TownCargo;
		if (totalRates == 0 && (!isTownCargo || (isTownCargo && !TownBus.Exists(town, cargo)))) { // 他社は1社であると仮定している
			return 70 * production / (GetLastMonthTransportedPercentage(cargo) + 70);
		} else if (count == 1 && isMine) {
			return production / (otherCompanies + 1);
		} else {
			return 70 * (production / (otherCompanies + 1)) / (totalRates + 70);
		}
	}

	function IsDirtyArround() {
		foreach(cargo in GetAccepting().GetCargos()) {
			if (PlaceProduction.Get().IsDirtyArround(GetLocation(), cargo)) {
				//HgLog.Info("Dirty["+AICargo.GetName(cargo)+"]");
				return true;
			}
		}
		return false;
	}

	function SetDirtyArround() {
		foreach(cargo in GetAccepting().GetCargos()) {
			PlaceProduction.Get().SetDirtyArround(GetLocation(), cargo);
		}
	}

	function IsEcsHardNewRouteDest(cargo) {
		if (HogeAI.Get().ecs && this instanceof HgIndustry && this.GetCargos().len() >= 2) { // ecsのマルチで受け入れるindustryは生産条件を満たすのが困難な事が多い。
			local traits = this.GetIndustryTraits();
			local cargoLabel = AICargo.GetCargoLabel(cargo);
			if (!(traits == "WOOL,LVST,/FICR,FISH,CERE," ||
					traits == "FERT,FOOD,/OLSD,FRUT,CERE," ||
					traits == "/OIL_,COAL," ||
					traits == "PETR,RFPR,/OLSD,OIL_," ||
					traits == "GOOD,/DYES,GLAS,STEL," ||
					(cargoLabel == "RFPR" && traits == "GOOD,/RFPR,GLAS,"))) {
				return true;
			}
		}
		return false;
	}


	function GetCoasts(cargo) {
		local placeDictionary = PlaceDictionary.Get();
		local id = Id() + ":" + cargo;
		if (this instanceof TownCargo) {
			local result;
			if (!placeDictionary.nearWaters.rawin(id) || placeDictionary.nearWaters[id] == true || placeDictionary.nearWaters[id] == false) {
				result = FindCoast(cargo);
				placeDictionary.nearWaters[id] <- [(result == null ? null : result.id), AITown.GetPopulation(town)];
				return result;
			} else {
				if (placeDictionary.nearWaters[id][0] == null) {
					local population = AITown.GetPopulation(town);
					if (placeDictionary.nearWaters[id][1] * 3 / 2 < population) {
						result = FindCoast(cargo);
						placeDictionary.nearWaters[id] = [(result == null ? null : result.id), population];
						return result;
					}
				}
				local coastsId = placeDictionary.nearWaters[id][0];
				return coastsId == null ? null : Coasts.idCoasts[coastsId];
			}
		} else {
			local result;
			if (!placeDictionary.nearWaters.rawin(id) || placeDictionary.nearWaters[id] == true || placeDictionary.nearWaters[id] == false) {
				result = FindCoast(cargo);
				//HgLog.Info("CheckNearWater "+this+" "+AICargo.GetName(cargo)+" result:"+result);
				placeDictionary.nearWaters[id] <- result == null ? null : result.id;
				return result;
			} else {
				local coastsId = placeDictionary.nearWaters[id];
				return coastsId == null ? null : Coasts.idCoasts[coastsId];
			}
		}
	}

	function FindCoast(cargo) {
		//HgLog.Info("CheckNearWater "+this+" "+AICargo.GetName(cargo));
		if (IsBuiltOnWater()) {
			local cur = GetLocation(); // 陸地に接しているIsBuiltOnWaterがある(firs)
			cur = Coasts.FindCoast(cur);
			if (cur != null) {
				local coasts = Coasts.GetCoasts(cur);
				if (coasts.coastType == Coasts.CT_POND) {
					return null;
				} else {
					return coasts;
				}
			} else {
				return GlobalCoasts;
			}
		}
		local coastTileList = FindCoastTileList(cargo);
		foreach(t, _ in coastTileList) {
			local result = Coasts.GetCoasts(t);
			if (result != null && result.coastType != Coasts.CT_POND) {
				return result;
			}
		}
		return null;
	}

	function IsNearWater(cargo) {
		local placeDictionary = PlaceDictionary.Get();
		local id = Id() + ":" + GetRadius() + ":" + cargo;
		if (placeDictionary.nearWaters.rawin(id)) {
			return placeDictionary.nearWaters[id];
		}
		local result = _IsNearWater(cargo);
		placeDictionary.nearWaters.rawset(id, result);
		return result;
	}

	// TownCargoでoverride

	function IsNearLand(cargo) {
		local key = Id() + "-" + cargo;
		local cache = Place.nearLandCache;
		if (cache.rawin(key)) {
			return cache.rawget(key);
		}
		local result = _IsNearLand(cargo);
		cache.rawset(key, result);
		return result;
	}

	function _IsNearLand(cargo) {
		//HgLog.Info("CheckNearWater "+this+" "+AICargo.GetName(cargo));
		if (!IsBuiltOnWater()) {
			return true;
		}

		local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		local tile;
		local gen = GetTiles(radius, cargo)
		while ((tile = resume gen) != null) {
			if (AITile.GetMaxHeight(tile) >= 1) {
				return true;
			}
		}
		return false;
	}

	function GetAllowedAirportLevel(airportType /*必要最小限のaiportType*/ , cargo) {
		local location = GetNoiseLevelLocation();
		local allowedNoise = GetAllowedNoise(airportType);
		local result = 0;
		foreach(airportTraints in Air.Get().GetAvailableAiportTraits()) {
			if (allowedNoise >= AIAirport.GetNoiseLevelIncrease(location, airportTraints.airportType)) {
				result = max(airportTraints.level, result);
			}
		}
		foreach(station in HgStation.SearchStation(this, AIStation.STATION_AIRPORT, cargo, IsAccepting())) {
			if (station.CanShareByMultiRoute(airportType)) {
				result = max(station.GetAirportTraits().level, result)
			}
		}
		return result;
	}

	function CanBuildAirport(airportType, cargo) {
		local key = Id() + "-" + airportType + "-" + cargo;
		local cache = Place.canBuildAirportCache;
		if (cache.rawin(key)) {
			return cache[key];
		}
		local result = _CanBuildAirport(airportType, cargo);
		cache[key] <- result;
		return result;
	}

	function _CanBuildAirport(airportType, cargo) {
		local location = GetNoiseLevelLocation();
		local noiseLevelIncrease = AIAirport.GetNoiseLevelIncrease(location, airportType);
		if (GetAllowedNoise(airportType) >= noiseLevelIncrease) {
			return true;
		}
		foreach(station in HgStation.SearchStation(this, AIStation.STATION_AIRPORT, cargo, IsAccepting())) {
			if (station.CanShareByMultiRoute(airportType) && Air.Get().IsCoverAiportType(station.GetAirportType(), airportType)) {
				return true;
			}
		}
		return false;
	}

	function IsMeetExceptProcessing() { // raw,Wharfが満たされているか
		local cargos = GetAccepting().GetCargos();
		local accept = 0;
		foreach(acceptCargo in cargos) {
			foreach(route in GetRoutesUsingDest()) {
				local prod = route.GetDelivableProduction(acceptCargo);
				//HgLog.Warning("GetAdditionalRouteIncome prod:"+prod+"["+AICargo.GetName(acceptCargo)+"] "+route);
				accept += prod;
			}
		}
		//HgLog.Warning("GetAdditionalRouteIncome sum:"+accept);
		if (IsRaw()) {
			return accept >= 27; // 80/3=27/月
		} else {
			return accept >= 213; // 640/3=213/月
		}
	}

	function GetDestRouteCargoIncome(cargo) {
		if (!IsIncreasable() || !IsProcessing() || IsRaw()) {
			return 0;
		}
		local usingRoutes = GetRoutesUsingSource();
		if (usingRoutes.len() == 0) {
			return 0;
		}
		local producingCargos = GetProducing().GetCargos();
		local result = 0;
		local baseRate = AdjustUsing(70, cargo, true);
		if (HogeAI.Get().firs) {
			local acceptingCargos = GetCargos();
			local meetsCargos = GetToMeetCargos();
			if (meetsCargos.rawin(cargo)) {
				baseRate = baseRate * meetsCargos.len() / acceptingCargos.len();
			} else {
				baseRate = baseRate * (meetsCargos.len() + 1) / acceptingCargos.len();
			}
		}
		foreach(usingRoute in usingRoutes) {
			local engineSet = usingRoute.GetLatestEngineSet();
			if (engineSet == null) {
				continue;
			}
			local cargoIncomes = engineSet.cargoIncomes;
			foreach(producingCargo in producingCargos) {
				if (!usingRoute.NeedsAdditionalProducingCargo(producingCargo)) {
					continue;
				}
				if (cargoIncomes.rawin(producingCargo)) {
					local cargoIncome = cargoIncomes[producingCargo];
					local rate = GetProducingRateInput(producingCargo, cargo) * baseRate / 100;
					result += cargoIncome * rate / 100;
					if (usingRoute instanceof TrainRoute) {
						if (usingRoute.returnRoute != null && !usingRoute.returnRoute.NeedsAdditionalProducingCargo(producingCargo)) {
							result += cargoIncome * rate / 100; // 復路の分。TODO: 転送やbidirectionも
						}
					}
				}
			}
		}
		return result;
	}

	function GetAdditionalRouteIncome(cargo) {
		if (!HogeAI.Get().firs) {
			return 0;
		}
		local cargos = GetAccepting().GetCargos();
		local isProcessing = IsProcessing();
		local isRaw = IsRaw();
		if (!isProcessing) {
			if (IsMeetExceptProcessing()) {
				return 0;
			}
		} else {
			if (GetToMeetCargos().rawin(cargo)) {
				return 0;
			}
		}
		local result = 0;
		foreach(route in GetRoutesUsingSource()) {
			if (CargoUtils.IsPaxOrMail(route.cargo)) { //PaxMailは増えない(HOTEL)
				return 0;
			}
			local engineSet = route.GetLatestEngineSet();
			if (engineSet != null) {
				if (isProcessing) {
					// processingは例えばaccept5種中2種満たすと、出力が1/5から2/5になる（つまり1/5増える）
					result += engineSet.routeIncome / cargos.len();
				} else {
					result += engineSet.routeIncome * 2; // raw,Wharfは3倍になる
				}
			}
		}
		return result;
	}

	function GetNotToMeetCargos() {
		return GetToMeetCargos(true);
	}

	function GetToMeetCargos(not = false) {
		local delivered = {}; // 他社が満たしているものは取れない
		foreach(route in GetAccepting().GetRoutesUsingDest()) {
			if (route.IsTransfer()) {
				continue;
			}
			foreach(cargo in route.GetCargos()) {
				if (route.GetCargoCapacity(cargo) >= 1) {
					delivered.rawset(cargo, 0);
				}
			}
		}
		local result = {};
		foreach(cargo in GetAccepting().GetCargos()) {
			if (not != delivered.rawin(cargo)) {
				result.rawset(cargo, cargo);
			}
		}
		return result;

	}

	function GetRectangle() {
		return Rectangle.Center(HgTile(GetLocation()), GetRadius());
	}

	function _tostring() {
		return GetName();
	}
}

class HgIndustry extends Place {
	static industryClosedDate = {};

	industry = null;
	isProducing = null;
	date = null;

	location = null;

	constructor(industry, isProducing, date = null) {
		this.industry = industry;
		this.isProducing = isProducing;
		this.date = date != null ? date : AIDate.GetCurrentDate();
	}

	function Save() {
		local t = {};
		t.name <- "HgIndustry";
		t.industry <- industry;
		t.isProducing <- isProducing;
		t.date <- date;
		return t;
	}

	function Id() {
		return "Industry:" + industry + ":" + isProducing;
	}

	function GetFacilityId() {
		return "Industry:" + industry;
	}

	function IsSamePlace(other) {
		if (other == null) {
			return false;
		}
		if (!(other instanceof HgIndustry)) {
			return false;
		}
		return industry == other.industry && isProducing == other.isProducing;
	}

	function GetName() {
		return AIIndustry.GetName(industry);
	}

	function GetLocation() {
		if (location == null) {
			location = AIIndustry.GetLocation(industry);
		}
		return location;
	}

	function GetRadius() {
		return 3;
	}

	function GetTiles(coverageRadius, cargo) {
		foreach(tile, _ in AcceptProducingTileList(GetTileList(coverageRadius), coverageRadius, cargo)) {
			yield tile;
		}
		return null;
	}

	function GetCargoTileList(coverageRadius, cargo) {
		return AcceptProducingTileList(GetTileList(coverageRadius), coverageRadius, cargo);
	}

	function AcceptProducingTileList(list, coverageRadius, cargo) {
		if (IsAcceptingAndProducing(cargo)) {
			list.Valuate(AITile.GetCargoProduction, cargo, 1, 1, coverageRadius);
			list.RemoveValue(0)
			list.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, coverageRadius);
			list.RemoveBelowValue(8)
		} else if (isProducing) {
			list.Valuate(AITile.GetCargoProduction, cargo, 1, 1, coverageRadius);
			list.RemoveValue(0)
		} else {
			list.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, coverageRadius);
			list.RemoveBelowValue(8)
		}
		return list;
	}

	function GetTileList(coverageRadius) {
		if (isProducing) {
			return AITileList_IndustryProducing(industry, coverageRadius);
		} else {
			return AITileList_IndustryAccepting(industry, coverageRadius);
		}
	}

	function FindCoastTileList(cargo) {
		local dockRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
		local tileList = GetTileList(dockRadius);
		tileList.Valuate(AITile.IsCoastTile);
		tileList.KeepValue(1);
		if (tileList.Count() == 0) {
			return tileList;
		}
		AcceptProducingTileList(tileList, dockRadius, cargo);
		return tileList;
	}

	function _IsNearWater(cargo) {
		if (IsBuiltOnWater()) {
			return true;
		}
		local coastTileList = FindCoastTileList(cargo);
		if (coastTileList.Count() == 0) {
			return false;
		}
		HogeAI.Get().pendingCoastTiles.push(coastTileList.Begin());
		return true;
	}


	function GetLastMonthTransportedPercentage(cargo) {
		return AIIndustry.GetLastMonthTransportedPercentage(industry, cargo);
	}

	function _GetCurrentExpectedProduction(cargo, vehicleType, isMine = false, callers = null) {
		return AdjustUsing(__GetCurrentExpectedProduction(cargo, vehicleType, isMine, callers), cargo, isMine);
	}

	function __GetCurrentExpectedProduction(cargo, vehicleType, isMine = false, callers = null) {
		if (IsProcessing()) {
			if (HogeAI.Get().firs) {
				local result = GetLastMonthProduction(cargo);
				local meetsCount = 0;
				local total = 0;
				local acceptingCargos = AICargoList_IndustryAccepting(industry);
				if (acceptingCargos.Count() >= 1) {
					local routes = GetRoutesUsingDest();
					foreach(cargoAccept, _ in acceptingCargos) {
						local meets = false;
						local rate = GetProducingRateInput(cargo, cargoAccept);
						foreach(route in routes) {
							if (route.IsTransfer()) continue;
							local r = route.GetDelivableProduction(cargoAccept, callers);
							//HgLog.Warning("GetExpectedProduction:"+r+" total:"+total+" ["+AICargo.GetName(cargoAccept)+"] "+route+" "+this);
							total += r * rate / 100;
							meets = true;
						}
						if (meets) meetsCount++;
					}
				}
				total = total * meetsCount / acceptingCargos.Count();
				return max(GetLastMonthProduction(cargo), total);
			} else {
				local total = 0;
				foreach(cargoAccept, _ in AICargoList_IndustryAccepting(industry)) {
					foreach(route in GetRoutesUsingDest()) {
						if (route.IsTransfer()) continue;
						local r = route.GetDelivableProduction(cargoAccept, callers);
						//HgLog.Warning("GetExpectedProduction:"+r+" total:"+total+" ["+AICargo.GetName(cargoAccept)+"] "+route+" "+this);
						total += r;
					}
				}
				return max(GetLastMonthProduction(cargo), total);
			}
		} else {
			return GetLastMonthProduction(cargo);
		}
	}


	function GetLastMonthProduction(cargo) {
		return PlaceProduction.Get().GetLastMonthProduction(industry, cargo);
	}

	function IsClosed() {
		if (industryClosedDate.rawin(industry)) {
			if (date < industryClosedDate[industry]) {
				return true;
			}
		}
		return false;
	}

	function GetCargos() {
		local cache = GetPlaceCache();
		if ("cargos" in cache) return cache.cargos;
		cache.cargos <- _GetCargos();
		return cache.cargos;
	}

	function _GetCargos() {
		if (isProducing) {
			return HgArray.AIListKey(AICargoList_IndustryProducing(industry)).array;
		} else {
			local traits = GetIndustryTraits();
			if (traits == "OIL_,PASS,/") { // 海上油田
				return HogeAI.Get().GetPaxMailCargos();
			}
			return HgArray.AIListKey(AICargoList_IndustryAccepting(industry)).array;
		}
	}

	function IsCargoAccepted(cargo) {
		return AIIndustry.IsCargoAccepted(industry, cargo) == AIIndustry.CAS_ACCEPTED;
	}

	function GetProducingCargos() {
		return GetProducing().GetCargos();
	}

	function IsAccepting() {
		return !isProducing;
	}

	function IsProducing() {
		return isProducing;
	}

	function GetAccepting() {
		if (isProducing) {
			return HgIndustry(industry, false, date);
		} else {
			return this;
		}
	}

	function GetProducing() {
		if (isProducing) {
			return this;
		} else {
			return HgIndustry(industry, true, date);
		}
	}

	function GetProducingOr(isProducing) {
		if (isProducing) {
			return GetProducing();
		} else {
			return GetAccepting();
		}
	}

	// 入力すると出力が増えるかどうか or 入力が無くて勝手に増えるかどうか
	function IsIncreasable() {
		local placeCache = GetPlaceCache();
		if (!("isIncreasable" in placeCache)) {
			placeCache.isIncreasable <- _IsIncreasable();
		}
		return placeCache.isIncreasable;
	}

	function _IsIncreasable() {
		if (HogeAI.Get().ecs || HogeAI.Get().yeti) {
			return true;
		}
		local industryType = AIIndustry.GetIndustryType(industry);
		local acceptingCargos = HgArray(GetAccepting().GetCargos());
		if (acceptingCargos.Count() == 0 && !AIIndustryType.ProductionCanIncrease(industryType)) {
			return false;
		}
		if (!AIIndustryType.IsProcessingIndustry(industryType) && !AIIndustryType.IsRawIndustry(industryType)) {
			foreach(producingCargo in GetProducing().GetCargos()) {
				if (acceptingCargos.Contains(producingCargo)) {
					return false; // 入出力に同じものがある(例:銀行)
				}
			}
		}

		return true;
	}


	function IsIncreasableInputCargo(inputCargo) {
		local traits = GetIndustryTraits();
		if (traits == "OIL_,PASS,/") { // 油田
			return false;
		}
		return true;
	}

	function IsRaw() {
		local traits = GetIndustryTraits();
		if (traits == "BDMT,/COAL,") { // Brick works(ECS)
			return false;
		}
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.IsRawIndustry(industryType);
	}

	function IsProcessing() {
		if (HogeAI.Get().ecs) {
			local traits = GetIndustryTraits();
			if (traits == "BDMT,/COAL,") { // Brick works(ECS)
				return true;
			}
		}
		local industryType = AIIndustry.GetIndustryType(industry);
		return AIIndustryType.IsProcessingIndustry(industryType);
	}

	function GetStockpiledCargo(cargo) {
		return AIIndustry.GetStockpiledCargo(industry, cargo);
	}

	function IsBuiltOnWater() {
		return AIIndustry.IsBuiltOnWater(industry);
	}

	function HasStation(vehicleType) {
		return vehicleType == AIVehicle.VT_WATER && AIIndustry.HasDock(industry);
	}

	function GetStationLocation(vehicleType) {
		if (vehicleType == AIVehicle.VT_WATER) {
			if (AIIndustry.HasDock(industry)) {
				return AIIndustry.GetDockLocation(industry);
			}
		}
		return null;
	}

	function GetIndustryTraits() {
		local chace = GetPlaceCache();
		if ("traits" in cache) return cache.traits;
		cache.traits <- _GetIndustryTraits();
		return cache.traits;
	}

	function _GetIndustryTraits() {
		local industryType = AIIndustry.GetIndustryType(industry);
		if (!AIIndustryType.IsValidIndustryType(industryType)) {
			return ""; // たぶんcloseしてる
		}
		local s = "";
		foreach(cargo, v in AIIndustryType.GetProducedCargo(industryType)) {
			s += AICargo.GetCargoLabel(cargo) + ",";
		}
		s += "/";
		foreach(cargo, v in AIIndustryType.GetAcceptedCargo(industryType)) {
			s += AICargo.GetCargoLabel(cargo) + ",";
		}
		return s;
	}

	function GetNoiseLevelLocation() {
		return GetLocation();
	}

	function GetAllowedNoise(airportType) {
		local town = AIAirport.GetNearestTown(GetNoiseLevelLocation(), airportType);
		return AITown.GetAllowedNoise(town);
	}

	function GetProducingRate(cargo) {
		if (HogeAI.Get().firs) {
			local prodRate = ProducingRate.Get().GetRates(AIIndustry.GetIndustryType(this.industry));
			if (prodRate != null) {
				local a = (prodRate.rawin(cargo) ? prodRate.rawget(cargo) : 0);
				//HgLog.Warning("GetProducingRate:"+AIIndustry.GetName(this.industry)+" ["+AICargo.GetName(cargo)+"]:"+a);
				return a;
			} else {
				return 50;
			}
		}
		return 100;
	}

	function GetProducingRateInput(cargo, inputCargo) {
		if (!IsCargoAccepted(inputCargo)) {
			return 0;
		}
		if (HogeAI.Get().firs) {
			local cargoNum = GetAccepting().GetCargos().len();
			if (cargoNum == 0) {
				return 100;
			}
			local meets = GetToMeetCargos();
			local meetNum = meets.len() + (meets.rawin(inputCargo) ? 0 : 1);
			local result = 100 * meetNum / cargoNum;
			local prodRate = ProducingRate.Get().GetRates(AIIndustry.GetIndustryType(this.industry));
			if (prodRate != null) {
				local a = (prodRate.rawin(cargo) ? prodRate.rawget(cargo) : 0) * result / 100;
				//HgLog.Warning("GetProducingRateInput:"+AIIndustry.GetName(this.industry)+" ["+AICargo.GetName(cargo)+"]:"+a);
				return a;

			} else {
				return result / 2; // 不明な場合はやや少なめに見る
			}
		}
		return 100;
	}

	function _tostring() {
		return GetName() + "(" + industry + "):" + (isProducing ? "P" : "A")
	}
}

class TownCargo extends Place {
	town = null;
	cargo = null;
	isProducing = null;

	location = null;

	constructor(town, cargo, isProducing) {
		this.town = town;
		this.cargo = cargo;
		this.isProducing = isProducing;
	}

	function Save() {
		local t = {};
		t.name <- "TownCargo";
		t.town <- town;
		t.cargo <- cargo;
		t.isProducing <- isProducing;
		return t;
	}

	function IsSamePlace(other) {
		if (other == null) {
			return false;
		}
		if (!(other instanceof TownCargo)) {
			return false;
		}
		return town == other.town;
	}

	function Id() {
		return "TownCargo:" + town + ":" + cargo + ":" + isProducing;
	}

	function GetFacilityId() {
		return "TownCargo:" + town;
	}

	function GetName() {
		return AITown.GetName(town);
	}

	function GetLocation() {
		if (location == null) {
			location = AITown.GetLocation(town);
		}
		return location;
	}


	function GetCargos() {
		if (cargo == null) {
			return [];
		}
		return [cargo];
	}

	function GetRadius() {
		return GetRadiusPopulation(AITown.GetPopulation(town));
	}

	static function GetRadiusPopulation(population) {
		if (population < 700) return 3;
		if (population < 1200) return 4;
		if (population < 1800) return 5;
		if (population < 2700) return 6;
		if (population < 3700) return 7;
		if (population < 5000) return 8;
		if (population < 6500) return 9;
		if (population < 8200) return 10;
		if (population < 10200) return 11;
		if (population < 12400) return 12;
		if (population < 14900) return 13;
		if (population < 17700) return 14;
		if (population < 20800) return 15;
		if (population < 24200) return 16;
		if (population < 27900) return 17;
		if (population < 32000) return 18;
		if (population < 36300) return 19;
		return max(3, (pow(population, 0.4) * 0.3).tointeger());
	}

	function GetCargoTileList(coverageRadius, cargo) {
		if (cargo != this.cargo) {
			HgLog.Warning("Cargo not match. expect:" + AICargo.GetName(this.cargo) + " but:" + AICargo.GetName(cargo));
			return AITileList();
		}
		local maxRadius = GetRadius();
		if (TownBus.CanUse(cargo) || HogeAI.Get().CanExtendCoverageAreaInTowns()) {
			maxRadius += coverageRadius; //paxはbusがある場合、遠くても良い
		}
		if (IsProducing()) {
			local tileList = Rectangle.Center(HgTile(GetLocation()), maxRadius).GetTileList();
			local bottom = CargoUtils.IsPaxOrMail(cargo) ? 8 : 1;
			tileList.Valuate(AITile.GetCargoProduction, cargo, 1, 1, coverageRadius);
			tileList.RemoveBelowValue(bottom);
			return tileList;
		} else {
			local tileList = Rectangle.Center(HgTile(GetLocation()), maxRadius).GetTileList();
			local bottom = AICargo.GetTownEffect(cargo) == AICargo.TE_GOODS ? 8 : 8;
			tileList.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, coverageRadius);
			tileList.RemoveBelowValue(bottom);
			return tileList;
		}
	}


	function GetTiles(coverageRadius, cargo) {
		if (cargo != this.cargo) {
			HgLog.Warning("Cargo not match. expect:" + AICargo.GetName(this.cargo) + " but:" + AICargo.GetName(cargo));
			return null;
		}

		local maxRadius = GetRadius(); // + coverageRadius;
		if (IsProducing()) {
			local tiles = Rectangle.Center(HgTile(GetLocation()), maxRadius).GetTilesOrderByInside();
			local bottom = CargoUtils.IsPaxOrMail(cargo) ? 8 : 1;
			foreach(tile, _ in tiles) {
				if (AITile.GetCargoProduction(tile, cargo, 1, 1, coverageRadius) >= bottom) {
					yield tile;
				}
			}
		} else {
			local tiles = Rectangle.Center(HgTile(GetLocation()), maxRadius).GetTilesOrderByOutside();
			local bottom = AICargo.GetTownEffect(cargo) == AICargo.TE_GOODS ? 8 : 8;
			foreach(tile, _ in tiles) {
				if (AITile.GetCargoAcceptance(tile, cargo, 1, 1, coverageRadius) >= bottom) {
					yield tile;
				}
			}
		}
		return null;
		/*
				result.Valuate(HogeAI.IsBuildable);
				result.KeepValue(1);
				result.Valuate(AITile.GetCargoAcceptance, cargo, 1, 1, coverageRadius);
				result.KeepAboveValue(17);
				return result;*/
	}

	function FindCoastTileList(cargo) {
		local r = GetRadius();
		if (!HogeAI.Get().IsDistantJoinStations() || HogeAI.Get().IsAvoidExtendCoverageAreaInTowns()) {
			r -= 2; // 船にとって街は遠い
		}
		local rectangle = Rectangle.Center(HgTile(GetLocation()), r);
		local tileList = rectangle.GetEdgeTileList();
		tileList.Valuate(AITile.IsCoastTile);
		tileList.KeepValue(1);
		return tileList;
	}

	function _IsNearWater(cargo) {
		return FindCoastTileList(cargo).Count() >= 1;
	}

	function GetNotUsedProductionMap(exceptPlatformTiles) {
		local result = {};
		local railRadius = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
		local roadRadius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
		local waterRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);

		local used = {};
		local exceptPlatformMap = {};
		foreach(t in exceptPlatformTiles) {
			exceptPlatformMap.rawset(t, 0);
		}

		foreach(tile in Rectangle.Center(HgTile(GetLocation()), GetRadius()).GetTiles()) {
			if (!AITile.IsStationTile(tile)) {
				continue;
			}
			if (!AICompany.IsMine(AITile.GetOwner(tile))) { // ライバル企業を避ける場合はこのチェックは不要
				continue;
			}
			local statoinId = AIStation.GetStationID(tile);
			if (!exceptPlatformMap.rawin(tile)) { // 作ったばかりでまだ評価が無いplatformを除外する
				if (!AIStation.HasCargoRating(statoinId, cargo)) {
					continue;
				}
				if (AIStation.GetCargoRating(statoinId, cargo) < 40) {
					continue;
				}
			}
			local radius;
			if (AIRail.IsRailStationTile(tile)) {
				radius = railRadius;
			} else if (AIRoad.IsRoadStationTile(tile)) {
				radius = roadRadius;
			} else if (AIAirport.IsAirportTile(tile)) {
				local airportType = AIAirport.GetAirportType(tile)
				radius = AIAirport.GetAirportCoverageRadius(airportType);
			} else if (AIMarine.IsDockTile(tile)) {
				radius = waterRadius;
			} else {
				continue; // unknown station
			}
			foreach(t in Rectangle.Center(HgTile(tile), radius).GetTiles()) {
				used.rawset(t, 0);
			}
		}
		foreach(tile in Rectangle.Center(HgTile(GetLocation()), max(6, GetRadius() - 6)).GetTiles()) {
			if (used.rawin(tile)) {
				continue;
			}
			if (AITile.GetCargoProduction(tile, cargo, 1, 1, 0) >= 1) {
				result.rawset(tile, AITile.GetCargoAcceptance(tile, cargo, 1, 1, 0));
			}
		}
		return result;
	}

	function _GetCurrentExpectedProduction(cargo, vehicleType, isMine = false, callers = null) {
		return GetExpectedProductionAll(cargo, vehicleType, isMine);
	}

	function GetCurrentProduction(cargo, isMine) {
		return AdjustUsing(GetLastMonthProduction(cargo), cargo, isMine);
	}

	function GetExpectedUsingDistantJoinStations() {
		local d = max(5, HogeAI.Get().maxStationSpread);
		return 200 + d * d * 2;
	}

	function GetExpectedProductionAll(cargo, vehicleType, isMine = false, preEstimate = false) {
		local production;
		/*if(isCurrent) {
			production = GetCurrentProduction(cargo, isMine);
		} else {
			production = GetLastMonthProduction(cargo);
		}*/
		production = AdjustUsing(GetLastMonthProduction(cargo), cargo, isMine);
		//HgLog.Info("GetLastMonthProduction:"+production+" "+AICargo.GetName(cargo)+" "+AITown.GetName(town));
		if (HogeAI.Get().IsDistantJoinStations() && !HogeAI.Get().IsAvoidExtendCoverageAreaInTowns()) {
			//production = production * 4 / 5; // スプレッドの隙間
			local d = HogeAI.Get().maxStationSpread;
			local additinalTownNum = max(0, (Place.GetTownDensity() * d * d).tointeger() - 1);
			production += additinalTownNum * Place.GetAverageTownPopulation() / (cargo == HogeAI.Get().GetPassengerCargo() ? 7 : 20);
			return min(production, cargo == HogeAI.Get().GetPassengerCargo() ?
				GetExpectedUsingDistantJoinStations() : GetExpectedUsingDistantJoinStations() * 2 / 5);
		} else if (TownBus.CanUse(cargo) && TownBus.IsReadyEconomy() && RoadRoute.GetVehicleNumRoom(RoadRoute) > 50) {
			production = production * 2 / 3; // バス停からはみ出る分
			if (vehicleType == AIVehicle.VT_ROAD) {
				return min(production, cargo == HogeAI.Get().GetPassengerCargo() ? 200 : 80);
			} else {
				return min(production, cargo == HogeAI.Get().GetPassengerCargo() ? 550 : 220);
			}
		} else {
			local minValue = cargo == HogeAI.Get().GetPassengerCargo() ? 200 : 80;
			if (vehicleType == AIVehicle.VT_ROAD) {
				minValue /= 2;
			} else if (vehicleType == AIVehicle.VT_WATER || vehicleType == AIVehicle.VT_AIR) {
				minValue = minValue / 1;
			}
			if (AITown.GetPopulation(town) < 700) {
				minValue /= 2; //人口密度が薄い
			}
			return min(minValue, production);
		}
		HgLog.Error("unknown vt:" + vehicleType);
	}

	function GetLastMonthProduction(cargo) {
		//if(RoadRoute.IsTooManyVehiclesForSupportRoute(RoadRoute)) {
		local r = AITown.GetLastMonthProduction(town, cargo);
		//HgLog.Info("GetLastMonthProduction:"+r+" "+AICargo.GetName(cargo)+" "+AITown.GetName(town));
		if (r > AITown.GetPopulation(town)) { // 異常値に対するバグ対応
			if (cargo == HogeAI.Get().GetPassengerCargo()) {
				r = AITown.GetPopulation(town) / 8;
			} else if (cargo == HogeAI.Get().GetMailCargo()) {
				r = AITown.GetPopulation(town) / 16;
			}
		}
		return r; // / 2;
	}

	function GetLastMonthTransportedPercentage(cargo) {
		return AITown.GetLastMonthTransportedPercentage(town, cargo);
	}

	function IsAccepting() {
		return !isProducing;
		/*		//TODO: STATION_TRUCK_STOP以外のケース
				local gen = this.GetTiles(AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP),cargo);
				return resume gen != null;*/
	}

	function IsCargoAccepted(cargo) {
		if (cargo == this.cargo) {
			return true;
		}
		if (AITile.GetCargoAcceptance(GetLocation(), cargo, 1, 1, GetRadius()) < 8) {
			return false;
		}
		/*
		local townEffect = AICargo.GetTownEffect(cargo);
		if(townEffect == AICargo.TE_GOODS) {
			return AITown.GetPopulation(town) >= 1200;
		}*/
		return true;

		/*
				local townEffect = AICargo.GetTownEffect(cargo);
				if(townEffect == AICargo.TE_GOODS) {
					return AITown.GetPopulation(town) >= 1200;
				}
				if(townEffect == AICargo.TE_PASSENGERS) {
					return AITown.GetPopulation(town) >= 200;
				}
				if(townEffect == AICargo.TE_MAIL) {
					return AITown.GetPopulation(town) >= 400;
				}
				if(townEffect == AICargo.TE_WATER || townEffect == AICargo.TE_FOOD ) {
					return AITown.GetPopulation(town) >= 1000;
				}*/
		return false;
	}

	function GetProducingCargos() {
		local pax = HogeAI.Get().GetPassengerCargo();
		local mail = HogeAI.Get().GetMailCargo();
		if (pax != null && mail != null && AITown.GetPopulation(town) >= 400) {
			if (IsProducing() && cargo != pax && cargo != mail) {
				return [cargo, pax, mail];
			}
			return [pax, mail];
		} else if (pax != null && IsProducing() && AITown.GetPopulation(town) >= 200) {
			if (cargo != pax) {
				return [cargo, pax];
			}
			return [pax];
		} else if (IsProducing()) {
			return [cargo];
		}
		return [];
	}

	function IsClosed() {
		return false;
	}

	function IsProducing() {
		return isProducing;
	}

	function GetAccepting() {
		if (!isProducing) {
			return this;
		} else {
			return TownCargo(town, cargo, false);
		}
	}

	function GetProducing() {
		if (isProducing) {
			return this;
		} else {
			if (Place.IsProducedByTown(cargo)) {
				return TownCargo(town, cargo, true);
			} else {
				return TownCargo(town, null, true);
			}
		}
	}

	function IsIncreasable() {
		return CanGrowth();
	}

	function IsIncreasableInputCargo(cargo) {
		return false;
	}

	function IsRaw() {
		return false;
	}

	function IsProcessing() {
		return false;
	}

	function GetStockpiledCargo(cargo) {
		return 0;
	}

	function IsBuiltOnWater() {
		return false;
	}

	function HasStation(vehicleType) {
		return false;
	}

	function GetStationLocation(vehicleType) {
		return null;
	}

	function GetNoiseLevelLocation() {
		return GetLocation() + GetRadius();
	}

	function GetAllowedNoise(airportType /*HgIndustryで使う*/ ) {
		return AITown.GetAllowedNoise(town) + (HogeAI.Get().isUseAirportNoise ? 1 : 0) /*離れれば空港建設できる事があるのでその分のバッファ*/ ;
	}

	function GetIndustryTraits() {
		return "";
	}

	function CanGrowth() {
		return TownBus.CanUse() && AITown.GetCargoGoal(town, AICargo.TE_WATER) == 0 && AITown.GetCargoGoal(town, AICargo.TE_FOOD) == 0;
	}

	function _tostring() {
		return GetName() + ":" + (isProducing ? "P" : "A") + "[" + AICargo.GetName(cargo) + "]";
	}
}

class CoastPlace extends Place {
	location = null;

	constructor(location) {
		this.location = location;
	}

	function Save() {
		local t = {};
		t.name <- "Coast";
		t.location <- location;
		return t;
	}

	function IsSamePlace(other) {
		if (other == null) {
			return false;
		}
		if (!(other instanceof CoastPlace)) {
			return false;
		}
		return location == other.location;
	}

	function Id() {
		return "Coast:" + location;
	}

	function GetFacilityId() {
		return Id();
	}

	function GetName() {
		return AITown.GetName(AITile.GetClosestTown(location)) + " Port";
	}

	function GetLocation() {
		return location;
	}


	function GetCargos() {
		return [];
	}

	function GetRadius() {
		return 12;
	}

	function GetCargoTileList(coverageRadius, cargo) {
		return TileListUtils.Generator(GetTiles(coverageRadius, cargo));
	}

	function GetTiles(coverageRadius, cargo) {
		local coasts = {};
		coasts.rawset(location, 0);
		local next = [location];
		while (next.len() >= 1) {
			local p = next.pop();
			local distance = coasts[p];
			foreach(d in HgTile.DIR4Index) {
				local t = p + d;
				if (!coasts.rawin(t) && AITile.IsCoastTile(t)) {
					if (distance < 12) {
						next.push(t);
					}
					coasts.rawset(t, distance + 1);
					yield t;
				}
			}
		}
		return null;
	}



	function GetExpectedProduction(cargo, vehicleType, isMine = false) {
		return 0;
	}

	function GetLastMonthProduction(cargo) {
		return 0;
	}

	function _GetCurrentExpectedProduction(cargo, vehicleType, isMine = false, callers = null) {
		return 0;
	}

	function GetLastMonthTransportedPercentage(cargo) {
		return 0;
	}

	function IsAccepting() {
		return false;
	}

	function IsCargoAccepted(cargo) {
		return false;
	}

	function GetProducingCargos() {
		return [];
	}

	function IsClosed() {
		return false;
	}

	function IsProducing() {
		return false;
	}

	function GetAccepting() {
		return this;
	}

	function GetProducing() {
		return this;
	}

	function IsIncreasable() {
		return false;
	}

	function IsRaw() {
		return false;
	}

	function IsProcessing() {
		return false;
	}

	function GetStockpiledCargo(cargo) {
		return 0;
	}

	function IsBuiltOnWater() {
		return false;
	}

	function HasStation(vehicleType) {
		return false;
	}

	function GetStationLocation(vehicleType) {
		return null;
	}

	function GetNoiseLevelLocation() {
		return GetLocation();
	}

	function GetAllowedNoise(airportType) {
		return 1000;
	}

	function GetCoasts(cargo) {
		return Coasts.GetCoasts(location);
	}

	function GetIndustryTraits() {
		return "";
	}


	function _tostring() {
		return "Coast:" + HgTile(location);
	}

}



class ProducingRate {
	static instance = GeneratorContainer(function() {
		return ProducingRate();
	});

	static function Get() {
		return ProducingRate.instance.Get();
	}

	lastCheckMonth = null;
	industryTypeProdRate = null;

	constructor() {
		industryTypeProdRate = {};
	}

	function GetCurrentMonth() {
		local currentDate = AIDate.GetCurrentDate();
		return (AIDate.GetMonth(currentDate) - 1) + AIDate.GetYear(currentDate) * 12;
	}

	function Check() {
		local currentMonth = GetCurrentMonth();
		if (lastCheckMonth == null || lastCheckMonth < currentMonth) {
			_Check();
			lastCheckMonth = currentMonth;
		}
	}

	function _Check() {
		local list = AIIndustryList();
		list.Valuate(AIIndustry.GetAmountOfStationsAround);
		list.RemoveValue(0);
		list.Valuate(AIIndustry.GetIndustryType);
		HgLog.Info("ProducingRate:" + list.Count());
		foreach(industry, industryType in list) {
			if (industryTypeProdRate.rawin(industryType)) {
				continue;
			}
			local cargoProd = {};
			foreach(cargo, _ in AIIndustryType.GetProducedCargo(industryType)) {
				local production = AIIndustry.GetLastMonthProduction(industry, cargo);
				if (production == 0) {
					break;
				}
				cargoProd.rawset(cargo, production);
			}
			if (cargoProd.len() >= 1) {
				local cargoProdRate = {};
				local maxProd = 0;
				foreach(cargo, prod in cargoProd) {
					maxProd = max(maxProd, prod);
				}
				foreach(cargo, prod in cargoProd) {
					cargoProdRate.rawset(cargo, prod * 100 / maxProd);
					HgLog.Info("ProducingRate:" + AIIndustry.GetName(industry) + " [" + AICargo.GetName(cargo) + "]:" + (prod * 100 / maxProd));
				}
				industryTypeProdRate.rawset(industryType, cargoProdRate);
			}
		}
	}

	function GetRates(industryType) {
		Check();
		if (!industryTypeProdRate.rawin(industryType)) {
			return null; // unknown;
		}
		return industryTypeProdRate.rawget(industryType);
	}
}