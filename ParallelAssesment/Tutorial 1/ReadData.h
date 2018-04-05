#pragma once
#include <fstream>
#include <string>
#include <vector>
#include <iostream>


#include "TemperatureData.h"


using namespace std;

class ReadData
{
public:
	ReadData();
	~ReadData();

	static void ReadDataIn(vector<string>* placeName, vector<int>* year, vector<int>* month,
		vector<int>* day, vector<string>* time, vector<float>* airTemp, string filename);

};

