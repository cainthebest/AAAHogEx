﻿/* $Id$ */

/**
 * A Road Pathfinder.
 *  This road pathfinder tries to find a buildable / existing route for
 *  road vehicles. You can changes the costs below using for example
 *  roadpf.cost.turn = 30. Note that it's not allowed to change the cost
 *  between consecutive calls to FindPath. You can change the cost before
 *  the first call to FindPath and after FindPath has returned an actual
 *  route. To use only existing roads, set cost.no_existing_road to
 *  cost.max_cost.
 */
class RoadPathFinder {
	_aystar_class = AyStar; //import("graph.aystar", "", 6)
	_max_cost = null; ///< The maximum cost for a route.
	_cost_tile = null; ///< The cost for a single tile.
	_cost_no_existing_road = null; ///< The cost that is added to _cost_tile if no road exists yet.
	_cost_turn = null; ///< The cost that is added to _cost_tile if the direction changes.
	_cost_slope = null; ///< The extra cost if a road tile is sloped.
	_cost_bridge_per_tile = null; ///< The cost per tile of a new bridge, this is added to _cost_tile.
	_cost_tunnel_per_tile = null; ///< The cost per tile of a new tunnel, this is added to _cost_tile.
	_cost_coast = null; ///< The extra cost for a coast tile.
	_cost_drivethroughstation = null;
	_cost_level_crossing = null;
	_cost_demolish_tile = null;
	_pathfinder = null; ///< A reference to the used AyStar object.
	_max_bridge_length = null; ///< The maximum length of a bridge that will be build.
	_max_tunnel_length = null; ///< The maximum length of a tunnel that will be build.
	_estimate_rate = null;

	engine = null;
	cost = null; ///< Used to change the costs.
	_running = null;
	_goals = null;
	debug = null;

	runnableRoadTypes = null;

	constructor() {
		this._max_cost = 10000000;
		this._estimate_rate = 2;
		this._goals = null;
		this._pathfinder = this._aystar_class(this, this._Cost, this._Estimate, this._Neighbours, this._CheckDirection);

		this.cost = this.Cost(this);
		this._running = false;
		this.debug = false;
	}

	/**
	 * Initialize a path search between sources and goals.
	 * @param sources The source tiles.
	 * @param goals The target tiles.
	 * @see AyStar::InitializePath()
	 */
	function InitializePath(sources, goals, ignoreTiles = []) {
		local nsources = [];

		foreach(node in sources) {
			nsources.push([node, 0xFF]);
		}
		this._pathfinder.InitializePath(nsources, goals, ignoreTiles);

		_goals = AIList();
		for (local i = 0; i < goals.len(); i++) {
			_goals.AddItem(goals[i], 0);
		}

		CheckRunnableRoadTypes();
	}

	function CheckRunnableRoadTypes() {
		runnableRoadTypes = RoadRouteBuilder.GetHasPowerRoadTypes(engine);
		foreach(roadType in runnableRoadTypes) {
			HgLog.Info("runnableRoadType:" + AIRoad.GetName(roadType) + " " + AIEngine.GetName(engine));
		}
	}

	/**
	 * Try to find the path as indicated with InitializePath with the lowest cost.
	 * @param iterations After how many iterations it should abort for a moment.
	 *  This value should either be -1 for infinite, or > 0. Any other value
	 *  aborts immediatly and will never find a path.
	 * @return A route if one was found, or false if the amount of iterations was
	 *  reached, or null if no path was found.
	 *  You can call this function over and over as long as it returns false,
	 *  which is an indication it is not yet done looking for a route.
	 * @see AyStar::FindPath()
	 */
	function FindPath(iterations);
};

class RoadPathFinder.Cost {
	_main = null;

	function _set(idx, val) {
		if (this._main._running) throw ("You are not allowed to change parameters of a running pathfinder.");

		switch (idx) {
			case "max_cost":
				this._main._max_cost = val;
				break;
			case "tile":
				this._main._cost_tile = val;
				break;
			case "no_existing_road":
				this._main._cost_no_existing_road = val;
				break;
			case "turn":
				this._main._cost_turn = val;
				break;
			case "slope":
				this._main._cost_slope = val;
				break;
			case "bridge_per_tile":
				this._main._cost_bridge_per_tile = val;
				break;
			case "tunnel_per_tile":
				this._main._cost_tunnel_per_tile = val;
				break;
			case "coast":
				this._main._cost_coast = val;
				break;
			case "max_bridge_length":
				this._main._max_bridge_length = val;
				break;
			case "max_tunnel_length":
				this._main._max_tunnel_length = val;
				break;
			default:
				throw ("the index '" + idx + "' does not exist");
		}

		return val;
	}

	function _get(idx) {
		switch (idx) {
			case "max_cost":
				return this._main._max_cost;
			case "tile":
				return this._main._cost_tile;
			case "no_existing_road":
				return this._main._cost_no_existing_road;
			case "turn":
				return this._main._cost_turn;
			case "slope":
				return this._main._cost_slope;
			case "bridge_per_tile":
				return this._main._cost_bridge_per_tile;
			case "tunnel_per_tile":
				return this._main._cost_tunnel_per_tile;
			case "coast":
				return this._main._cost_coast;
			case "max_bridge_length":
				return this._main._max_bridge_length;
			case "max_tunnel_length":
				return this._main._max_tunnel_length;
			default:
				throw ("the index '" + idx + "' does not exist");
		}
	}

	constructor(main) {
		this._main = main;
	}
};

function RoadPathFinder::FindPath(iterations) {
	local test_mode = AITestMode();
	local ret = this._pathfinder.FindPath(iterations);
	this._running = (ret == false) ? true : false;
	return ret;
}

function RoadPathFinder::_GetBridgeNumSlopes(end_a, end_b) {
	local slopes = 0;
	local direction = (end_b - end_a) / AIMap.DistanceManhattan(end_a, end_b);
	local slope = AITile.GetSlope(end_a);
	if (!((slope == AITile.SLOPE_NE && direction == 1) || (slope == AITile.SLOPE_SE && direction == -AIMap.GetMapSizeX()) ||
			(slope == AITile.SLOPE_SW && direction == -1) || (slope == AITile.SLOPE_NW && direction == AIMap.GetMapSizeX()) ||
			slope == AITile.SLOPE_N || slope == AITile.SLOPE_E || slope == AITile.SLOPE_S || slope == AITile.SLOPE_W)) {
		slopes++;
	}

	local slope = AITile.GetSlope(end_b);
	direction = -direction;
	if (!((slope == AITile.SLOPE_NE && direction == 1) || (slope == AITile.SLOPE_SE && direction == -AIMap.GetMapSizeX()) ||
			(slope == AITile.SLOPE_SW && direction == -1) || (slope == AITile.SLOPE_NW && direction == AIMap.GetMapSizeX()) ||
			slope == AITile.SLOPE_N || slope == AITile.SLOPE_E || slope == AITile.SLOPE_S || slope == AITile.SLOPE_W)) {
		slopes++;
	}
	return slopes;
}

function RoadPathFinder::DebugSign(tile, text) {
	if (debug) {
		local execMode = AIExecMode();
		AISign.BuildSign(tile, text)
	}
}

function RoadPathFinder::_Cost(self, path, new_tile, new_direction, mode) {
	/* path == null means this is the first node of a path, so the cost is 0. */
	if (path == null) return 0;
	self.DebugSign(new_tile, path.GetCost().tostring());

	local prev_tile = path.GetTile();

	/* If the new tile is a bridge / tunnel tile, check whether we came from the other
	 * end of the bridge / tunnel or if we just entered the bridge / tunnel. */
	if (AIBridge.IsBridgeTile(new_tile)) {
		if (AIBridge.GetOtherBridgeEnd(new_tile) != prev_tile) return path.GetCost() + self._cost_tile;
		return path.GetCost() + AIMap.DistanceManhattan(new_tile, prev_tile) * self._cost_tile + self._GetBridgeNumSlopes(new_tile, prev_tile) * self._cost_slope;
	}
	if (AITunnel.IsTunnelTile(new_tile)) {
		if (AITunnel.GetOtherTunnelEnd(new_tile) != prev_tile) return path.GetCost() + self._cost_tile;
		return path.GetCost() + AIMap.DistanceManhattan(new_tile, prev_tile) * self._cost_tile;
	}

	/* If the two tiles are more then 1 tile apart, the pathfinder wants a bridge or tunnel
	 * to be build. It isn't an existing bridge / tunnel, as that case is already handled. */
	local d = AIMap.DistanceManhattan(new_tile, prev_tile);
	if (d > 1) {
		/* Check if we should build a bridge or a tunnel. */
		local cost = path.GetCost() + d * (self._cost_tile + self._cost_no_existing_road + self._cost_tunnel_per_tile);
		if (AITunnel.GetOtherTunnelEnd(new_tile) != prev_tile) {
			cost += self._GetBridgeNumSlopes(new_tile, prev_tile) * self._cost_slope;
		}
		return cost;
	}

	/* Check for a turn. We do this by substracting the TileID of the current node from
	 * the TileID of the previous node and comparing that to the difference between the
	 * previous node and the node before that. */
	local cost = self._cost_tile;
	if (path.GetParent() != null && (prev_tile - path.GetParent().GetTile()) != (new_tile - prev_tile) &&
		AIMap.DistanceManhattan(path.GetParent().GetTile(), prev_tile) == 1) {
		cost += self._cost_turn;
	}

	/* Check if the new tile is a coast tile. */
	if (AITile.IsCoastTile(new_tile)) {
		cost += self._cost_coast;
	}

	/* Check if the last tile was sloped. */
	if (path.GetParent() != null && !AIBridge.IsBridgeTile(prev_tile) && !AITunnel.IsTunnelTile(prev_tile) &&
		self._IsSlopedRoad(path.GetParent().GetTile(), prev_tile, new_tile)) {
		cost += self._cost_slope;
	}

	if (!AIRoad.AreRoadTilesConnected(prev_tile, new_tile)) {
		cost += self._cost_no_existing_road;
		if (!AIRoad.BuildRoad(prev_tile, new_tile)) {
			cost += self._cost_demolish_tile;
		}
	}

	if (AIRoad.IsDriveThroughRoadStationTile(new_tile)) {
		cost += self._cost_drivethroughstation;
	}

	if (AITile.HasTransportType(new_tile, AITile.TRANSPORT_RAIL)) {
		cost += self._cost_level_crossing;
	}
	return path.GetCost() + cost;
}

function RoadPathFinder::_Estimate(self, cur_tile, cur_direction, goal_tiles) {
	local min_cost = self._max_cost;
	/* As estimate we multiply the lowest possible cost for a single tile with
	 * with the minimum number of tiles we need to traverse. */
	foreach(tile in goal_tiles) {
		min_cost = min(AIMap.DistanceManhattan(cur_tile, tile) * 100 /*self._cost_tile*/ , min_cost);
	}
	return min_cost * self._estimate_rate;
}

function RoadPathFinder::_Neighbours(self, path, cur_node) {
	/* self._max_cost is the maximum path cost, if we go over it, the path isn't valid. */
	if (path.GetCost() >= self._max_cost) return [];
	local tiles = [];

	if (path.mode == null) {
		path.mode = {};
	}

	/* Check if the current tile is part of a bridge or tunnel. */
	if ((AIBridge.IsBridgeTile(cur_node) || AITunnel.IsTunnelTile(cur_node)) &&
		AITile.HasTransportType(cur_node, AITile.TRANSPORT_ROAD)) {
		local other_end = AIBridge.IsBridgeTile(cur_node) ? AIBridge.GetOtherBridgeEnd(cur_node) : AITunnel.GetOtherTunnelEnd(cur_node);
		local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
		if (self._AreRoadTilesConnected(cur_node, next_tile) || AITile.IsBuildable(next_tile) || AIRoad.IsRoadTile(next_tile)) {
			tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), path.mode]);
		}
		/* The other end of the bridge / tunnel is a neighbour. */
		tiles.push([other_end, self._GetDirection(next_tile, cur_node, true) << 4, path.mode]);
	} else if (path.GetParent() != null && AIMap.DistanceManhattan(cur_node, path.GetParent().GetTile()) > 1) {
		local other_end = path.GetParent().GetTile();
		local next_tile = cur_node + (cur_node - other_end) / AIMap.DistanceManhattan(cur_node, other_end);
		if (self._AreRoadTilesConnected(cur_node, next_tile) || AIRoad.BuildRoad(cur_node, next_tile)) {
			tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), path.mode]);
		}
	} else {
		/* Check all tiles adjacent to the current tile. */
		foreach(offset in HgTile.DIR4Index) {
			local next_tile = cur_node + offset;
			/* We add them to the to the neighbours-list if one of the following applies:
			 * 1) There already is a connections between the current tile and the next tile.
			 * 2) We can build a road to the next tile.
			 * 3) The next tile is the entrance of a tunnel / bridge in the correct direction. */
			if (AITile.HasTransportType(next_tile, AITile.TRANSPORT_RAIL) && AICompany.IsMine(AITile.GetOwner(next_tile))) {
				continue;
			}
			if (self._AreRoadTilesConnected(cur_node, next_tile)) {
				tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), path.mode]);
			} else if ( /*(AITile.IsBuildable(next_tile) || AIRoad.IsRoadTile(next_tile)) &&*/
				(path.GetParent() == null || AIRoad.CanBuildConnectedRoadPartsHere(cur_node, path.GetParent().GetTile(), next_tile))) {
				if (AIRoad.BuildRoad(cur_node, next_tile)) {
					tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), path.mode]);
				} else if (!AIRoad.IsRoadDepotTile(cur_node) //接続方向が制限されるので除外 TODO:接続方向は調べられる
					&&
					!AIRoad.IsRoadStationTile(cur_node) &&
					!self.IsBusyRoad(cur_node) &&
					self.IsTownBuilding(next_tile)) {
					local town = AITile.GetTownAuthority(next_tile);
					if (AITown.IsValidTown(town)) {
						local mode = clone path.mode;
						if (!mode.rawin(town)) {
							mode.rawset(town, max(0, (AITown.GetRating(town, AICompany.COMPANY_SELF) - 2) * 2 / 3));
						}
						if (mode[town] >= 1) {
							mode[town]--;
							tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), mode]);
						}
					}
				} else if (self.IsTownBuilding(cur_node) &&
					((AITile.IsBuildable(next_tile) ||
						(AITile.HasTransportType(next_tile, AITile.TRANSPORT_ROAD) && !self.IsBusyRoad(next_tile))))) {
					// cur_nodeがDemolish予定のタイルで、next_tileはDemolish要らないケース
					tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false), path.mode]);
				}
			}
			/* else if (self._CheckTunnelBridge(cur_node, next_tile)) { すでに2行前のBuildRoadによってチェックさている。逆にここまで来るという事は次のタイルへ接続できない
							tiles.push([next_tile, self._GetDirection(cur_node, next_tile, false)]);
						}*/
		}
		if (path.GetParent() != null) {
			local bridges = self._GetTunnelsBridges(path.GetParent().GetTile(), cur_node, self._GetDirection(path.GetParent().GetTile(), cur_node, true) << 4, path);
			foreach(tile in bridges) {
				tiles.push(tile);
			}
		}
	}
	return tiles;
}

function RoadPathFinder::IsTownBuilding(tile) {
	return !AITile.IsBuildable(tile) &&
		AITile.DemolishTile(tile) &&
		AITile.GetOwner(tile) == AICompany.COMPANY_INVALID &&
		!AITile.IsRiverTile(tile) &&
		!AIBridge.IsBridgeTile(tile) // pathfinderが狂う可能性。実際には壊れていない状態で探索が続くので
		&&
		!AITunnel.IsTunnelTile(tile);
}

function RoadPathFinder::IsBusyRoad(tile) {
	if (!AIRoad.BuildDriveThroughRoadStation(tile, tile + 1, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW)) {
		return AIError.GetLastError() == AIError.ERR_VEHICLE_IN_THE_WAY && AITile.HasTransportType(tile, AITile.TRANSPORT_ROAD);
	}
	return false;
}


function RoadPathFinder::_AreRoadTilesConnected(cur, next) {
	if (!AIRoad.AreRoadTilesConnected(cur, next)) {
		return false;
	}
	foreach(roadType in runnableRoadTypes) {
		local r = AIRoad.ConvertRoadType(next, next, roadType);
		//HgLog.Info("ConvertRoadType("+HgTile(next)+","+AIRoad.GetName(roadType)+")="+r+" "+AIError.GetLastErrorString());
		if (r || AIError.GetLastError() == AIRoad.ERR_UNSUITABLE_ROAD /* || AIError.GetLastError() == AIError.ERR_ALREADY_BUILT*/ ) {
			return true;
		}

		/*	通れなくてもtrueが返る
				if(AIRoad.HasRoadType(next, roadType)) { // TODO: 速度低下を起こす場合のコスト
					HgLog.Info("HasRoadType("+HgTile(next)+","+AIRoad.GetName(roadType)+")=true");
					return true;
				}*/
	}
	return false;
}
/*
function RoadPathFinder::_BuildRoad(a,b) {
	local accounting = AIAccounting();
	local result = AIRoad.BuildRoad(a,b);
	if(_IsTooExpensive(accounting.GetCosts())) {
		return false;
	}
	return result;
}


function RoadPathFinder::_BuildBridge(a,b,c,d) {
	local accounting = AIAccounting();
	local result = AIRoad.BuildBridge(a,b,c,d);
	if(_IsTooExpensive(accounting.GetCosts())) {
		return false;
	}
	return result;
}

function RoadPathFinder::_BuildTunnel(a,b) {
	local accounting = AIAccounting();
	local result = AIRoad.BuildTunnel(a,b);
	if(_IsTooExpensive(accounting.GetCosts())) {
		return false;
	}
	return result;
}

function RoadPathFinder::_IsTooExpensive(cost) {
	return usableMoney < cost;
}*/


function RoadPathFinder::_CheckDirection(self, tile, existing_direction, new_direction) {
	return false;
}

function RoadPathFinder::_GetDirection(from, to, is_bridge) {
	if (!is_bridge && AITile.GetSlope(to) == AITile.SLOPE_FLAT) return 0xFF;
	if (from - to == 1) return 1;
	if (from - to == -1) return 2;
	if (from - to == AIMap.GetMapSizeX()) return 4;
	if (from - to == -AIMap.GetMapSizeX()) return 8;
}

/**
 * Get a list of all bridges and tunnels that can be build from the
 * current tile. Bridges will only be build starting on non-flat tiles
 * for performance reasons. Tunnels will only be build if no terraforming
 * is needed on both ends.
 */

function RoadPathFinder::_GetTunnelsBridges(last_node, cur_node, bridge_dir, path) {
	local slope = AITile.GetSlope(cur_node);
	if (slope == AITile.SLOPE_FLAT && AITile.IsBuildable(cur_node + (cur_node - last_node))) return [];
	local tiles = [];
	for (local i = 2; i < this._max_bridge_length; i++) {
		local bridge_list = AIBridgeList_Length(i + 1);
		local target = cur_node + i * (cur_node - last_node);
		if (!bridge_list.IsEmpty() && !_goals.HasItem(target) &&
			AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), cur_node, target)) {
			tiles.push([target, bridge_dir, path.mode]);
		}
	}

	if (slope != AITile.SLOPE_SW && slope != AITile.SLOPE_NW && slope != AITile.SLOPE_SE && slope != AITile.SLOPE_NE) return tiles;
	local other_tunnel_end = AITunnel.GetOtherTunnelEnd(cur_node);
	if (!AIMap.IsValidTile(other_tunnel_end)) return tiles;

	local tunnel_length = AIMap.DistanceManhattan(cur_node, other_tunnel_end);
	local prev_tile = cur_node + (cur_node - other_tunnel_end) / tunnel_length;
	if (AITunnel.GetOtherTunnelEnd(other_tunnel_end) == cur_node && tunnel_length >= 2 &&
		prev_tile == last_node && tunnel_length < _max_tunnel_length && AITunnel.BuildTunnel(AIVehicle.VT_ROAD, cur_node)) {
		tiles.push([other_tunnel_end, bridge_dir, path.mode]);
	}
	return tiles;
}

function RoadPathFinder::_IsSlopedRoad(start, middle, end) {
	local NW = 0; //Set to true if we want to build a road to / from the north-west
	local NE = 0; //Set to true if we want to build a road to / from the north-east
	local SW = 0; //Set to true if we want to build a road to / from the south-west
	local SE = 0; //Set to true if we want to build a road to / from the south-east

	if (middle - AIMap.GetMapSizeX() == start || middle - AIMap.GetMapSizeX() == end) NW = 1;
	if (middle - 1 == start || middle - 1 == end) NE = 1;
	if (middle + AIMap.GetMapSizeX() == start || middle + AIMap.GetMapSizeX() == end) SE = 1;
	if (middle + 1 == start || middle + 1 == end) SW = 1;

	/* If there is a turn in the current tile, it can't be sloped. */
	if ((NW || SE) && (NE || SW)) return false;

	local slope = AITile.GetSlope(middle);
	/* A road on a steep slope is always sloped. */
	if (AITile.IsSteepSlope(slope)) return true;

	/* If only one corner is raised, the road is sloped. */
	if (slope == AITile.SLOPE_N || slope == AITile.SLOPE_W) return true;
	if (slope == AITile.SLOPE_S || slope == AITile.SLOPE_E) return true;

	if (NW && (slope == AITile.SLOPE_NW || slope == AITile.SLOPE_SE)) return true;
	if (NE && (slope == AITile.SLOPE_NE || slope == AITile.SLOPE_SW)) return true;

	return false;
}

function RoadPathFinder::_CheckTunnelBridge(current_tile, new_tile) {
	if (!AIBridge.IsBridgeTile(new_tile) && !AITunnel.IsTunnelTile(new_tile)) return false;
	local dir = new_tile - current_tile;
	local other_end = AIBridge.IsBridgeTile(new_tile) ? AIBridge.GetOtherBridgeEnd(new_tile) : AITunnel.GetOtherTunnelEnd(new_tile);
	local dir2 = other_end - new_tile;
	if ((dir < 0 && dir2 > 0) || (dir > 0 && dir2 < 0)) return false;
	dir = abs(dir);
	dir2 = abs(dir2);
	if ((dir >= AIMap.GetMapSizeX() && dir2 < AIMap.GetMapSizeX()) ||
		(dir < AIMap.GetMapSizeX() && dir2 >= AIMap.GetMapSizeX())) return false;

	return true;
}