/**
* An area object defining an area via coordinates inside a map.
* Used to check if the provided location vector is inside the defined area.
* The total area is defined by one or more subareas, each defined by 6 coordinates.
* The 6 coords define the min and max of each direction: x,y,z
* The area is usually specified by adding subareas in event PreBeginPlay().
*/
class Area extends Object;

var float MAX_FLOAT;
var float MIN_FLOAT;

struct SubArea {
	var float XMIN;
	var float XMAX;
	var float YMIN;
	var float YMAX;
	var float ZMIN;
	var float ZMAX;
};

var array<SubArea> area;

/**
* Adds a subarea to include in the location check.
* Default values always include the specific location.
*/
function addArea(	optional float xMin = MIN_FLOAT,
					optional float xMax = MAX_FLOAT,
					optional float yMin = MIN_FLOAT,
					optional float yMax = MAX_FLOAT,
					optional float zMin = MIN_FLOAT,
					optional float zMax = MAX_FLOAT) {
	local SubArea newArea;

	newArea.XMIN = xMin;
	newArea.XMAX = xMax;
	newArea.YMIN = yMin;
	newArea.YMAX = yMax;
	newArea.ZMIN = zMin;
	newArea.ZMAX = zMax;

	area.addItem(newArea);
}

/**
* Return true if the provided location is inside this area or no subarea was added beforehand.
*/
function bool isInside(vector loc) {
	local SubArea a;

	if (area.length == 0) return true;

	foreach area(a) {
		if (subAreaContains(a, loc)) return true;
	}

	return false;
}

/**
* Returns a direction inwards of this area, based on the provided location.
*/
function vector getDirInwards(vector refLoc) {
	local vector dirInwards;
	local SubArea a;

	a = pickSubarea(refLoc);

	switch (pickClosestBorder(a, refLoc)) {
		case "XMAX":
			dirInwards.x = -1;
			break;
		case "XMIN":
			dirInwards.x = 1;
			break;
		case "YMAX":
			dirInwards.y = -1;
			break;
		case "YMIN":
			dirInwards.y = 1;
			break;
		case "ZMAX":
			dirInwards.z = -1;
			break;
		case "ZMIN":
			dirInwards.z = 1;
			break;
	}

	return dirInwards;
}

private function SubArea pickSubarea(vector loc) {
	local SubArea a;

	if (area.length == 0) return a;

	foreach area(a) {
		if (subAreaContains(a, loc)) return a;
	}

	return area[0];
}

private function String pickClosestBorder(Subarea a, vector loc) {
	local String closestBorder;
	local float closestBorderDist;
	closestBorderDist = MAX_FLOAT;

	if (a.XMIN != MIN_FLOAT && abs(loc.x - a.XMIN) < closestBorderDist) {
		closestBorder = "XMIN";
		closestBorderDist = abs(loc.x - a.XMIN);
	}
	if (a.XMAX != MAX_FLOAT && abs(loc.x - a.XMAX) < closestBorderDist) {
		closestBorder = "XMAX";
		closestBorderDist = abs(loc.x - a.XMAX);
	}
	if (a.YMIN != MIN_FLOAT && abs(loc.y - a.YMIN) < closestBorderDist) {
		closestBorder = "YMIN";
		closestBorderDist = abs(loc.y - a.YMIN);
	}
	if (a.YMAX != MAX_FLOAT && abs(loc.y - a.YMAX) < closestBorderDist) {
		closestBorder = "YMAX";
		closestBorderDist = abs(loc.y - a.YMAX);
	}
	if (a.ZMIN != MIN_FLOAT && abs(loc.z - a.ZMIN) < closestBorderDist) {
		closestBorder = "ZMIN";
		closestBorderDist = abs(loc.z - a.ZMIN);
	}
	if (a.ZMAX != MAX_FLOAT && abs(loc.z - a.ZMAX) < closestBorderDist) {
		closestBorder = "ZMAX";
		closestBorderDist = abs(loc.z - a.ZMAX);
	}

	return closestBorder;
}

private function bool subAreaContains(SubArea a, vector loc) {
	return	loc.x > a.xMin &&
			loc.x < a.xMax &&
			loc.y > a.yMin &&
			loc.y < a.yMax &&
			loc.z > a.zMin &&
			loc.z < a.zMax;
}


defaultproperties
{
	MAX_FLOAT = 3.403e38;
	MIN_FLOAT = -3.403e38;
}
