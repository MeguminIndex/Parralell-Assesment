#pragma once
#include <fstream>
#include <string>
#include <vector>
using namespace std;

class TemperatureData
{
public:
	string stationName;
	int year =0;
	int month =0;
	int day =0;
	int time =0;//(HHMM)
	float airTemperature =0.0f;
};