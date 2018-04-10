#include "ReadData.h"
#include <math.h>


ReadData::ReadData()
{
}


ReadData::~ReadData()
{
}


void ReadData::ReadDataIn(vector<string>* placeName, vector<int>* year, vector<int>* month,
	vector<int>* day, vector<string>* time, vector<float>* airTemp, string filename)
{

	ifstream file(filename);
	string tmpLine;

	int n = 0;

	string subTmp;
	string delimiter = " ";
	size_t  delimiterInd;// = tmpLine.find(delimiter);

	string placeT = "";
	int yearT = 0;
	int monthT = 0;
	int dayT = 0;
	string timeT = "0000";
	float airT = 0;

	while (getline(file, tmpLine))
	{
		if (tmpLine.empty())
			continue;

		//TemperatureData tmpData;
		 subTmp;
		 delimiter = " ";
		  delimiterInd;// = tmpLine.find(delimiter);

		 placeT = "";
		 yearT = 0;
		 monthT = 0;
		 dayT = 0;
		 timeT = "0000";
		 airT = 0;

#pragma region oldParse
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());		
		//try {
		//	tmpData.stationName = subTmp;
		//	//cout << "stationName: " << subTmp << endl;
		//}
		//catch (exception e){
		//	cout << "stationName: failed to convert to Int " << endl;
		//}

		//delimiterInd = tmpLine.find(delimiter);
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());

		//try {
		//	tmpData.year = stoi(subTmp);
		//	//cout << "YEAR: " << subTmp << endl;
		//}
		//catch(exception e){
		//	cout << "Year: failed to convert to Int " << endl;
		//}

		//
		//delimiterInd = tmpLine.find(delimiter);
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());	
		//try {
		//	tmpData.month = stoi(subTmp);
		//	//cout << "Month: " << subTmp << endl;
		//}
		//catch (exception e) {
		//	cout << "Month: failed to convert to Int " << endl;
		//}

		//delimiterInd = tmpLine.find(delimiter);
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());		
		//try {
		//	tmpData.day = stoi(subTmp);
		//	//cout << "Day: " << subTmp << endl;
		//}
		//catch (exception e) {
		//	cout << "Day: failed to convert to Int " << endl;
		//}


		//delimiterInd = tmpLine.find(delimiter);
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());	
		//try {
		//	tmpData.time = stoi(subTmp);
		//	//cout << "Time: " << subTmp << endl;
		//}
		//catch (exception e) {
		//	cout << "Time: failed to convert to Int " << endl;
		//}
		//


		//delimiterInd = tmpLine.find(delimiter);
		//subTmp = tmpLine.substr(0, delimiterInd);
		//tmpLine.erase(0, delimiterInd + delimiter.length());
		//
		//try {
		//	tmpData.airTemperature = stof(subTmp);
		//	//cout << "Temp: " << subTmp << endl;
		//}
		//catch (exception e) {
		//	cout << "Temp: failed to convert to float " << endl;
		//}

#pragma endregion

		for (int i = 0; i <6; i++)
		{
			

			delimiterInd = tmpLine.find(delimiter);
			subTmp = tmpLine.substr(0, delimiterInd);
			tmpLine.erase(0, delimiterInd + delimiter.length());

			try {

				switch (i)
				{
				case 0:
					placeT = subTmp;
					break;
				case 1:
					yearT = stoi(subTmp);
					break;
				case 2:
					monthT = stoi(subTmp);
					break;
				case 3:
					dayT = stoi(subTmp);
					break;
				case 4:
					timeT = subTmp;
					break;
				case 5:
					//float x = stod(subTmp) * 10;

					//airT = ceil(x);
					airT = stod(subTmp);
					break;

				}
			}
			catch (exception e)
			{

			}

		}

		//out->push_back(tmpData);#

		placeName->push_back(placeT);
		year->push_back(yearT);
		month->push_back(monthT);
		day->push_back(dayT);
		time->push_back(timeT);
		airTemp->push_back(airT);

		n++;
	}

}
