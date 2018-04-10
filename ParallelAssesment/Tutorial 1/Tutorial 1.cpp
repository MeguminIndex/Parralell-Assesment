#define CL_USE_DEPRECATED_OPENCL_1_2_APIS
#define __CL_ENABLE_EXCEPTIONS

#include <iostream>
#include <iomanip>
#include <vector>

#include <CL/cl.hpp>
#include "Utils.h"

//my Classes
#include "ReadData.h"
#include "TemperatureData.h"

using namespace std;

void print_help() { 
	cerr << "Application usage:" << endl;

	cerr << "  -p : select platform " << endl;
	cerr << "  -d : select device" << endl;
	cerr << "  -l : list all platforms and devices" << endl;
	cerr << "  -h : print this message" << endl;
}

int main(int argc, char **argv) {
	//Part 1 - handle command line options such as device selection, verbosity, etc.
	int platform_id = 0;
	int device_id = 0;

	for (int i = 1; i < argc; i++)	{
		if ((strcmp(argv[i], "-p") == 0) && (i < (argc - 1))) { platform_id = atoi(argv[++i]); }
		else if ((strcmp(argv[i], "-d") == 0) && (i < (argc - 1))) { device_id = atoi(argv[++i]); }
		else if (strcmp(argv[i], "-l") == 0) { cout << ListPlatformsDevices() << endl; }
		else if (strcmp(argv[i], "-h") == 0) { print_help(); }
	}

	//detect any potential exceptions
	try {
		//Part 2 - host operations
		//2.1 Select computing devices
		cl::Context context = GetContext(platform_id, device_id);

		//display the selected device
		cout << "Runinng on " << GetPlatformName(platform_id) << ", " << GetDeviceName(platform_id, device_id) << endl;

		//create a queue to which we will push commands for the device
		cl::CommandQueue queue(context, CL_QUEUE_PROFILING_ENABLE);

		//2.2 Load & build the device code
		cl::Program::Sources sources;

		AddSources(sources, "my_kernels.cl");

		cl::Program program(context, sources);

		try {
			program.build();
		}
		//display kernel building errors
		catch (const cl::Error& err) {
			std::cout << "Build Status: " << program.getBuildInfo<CL_PROGRAM_BUILD_STATUS>(context.getInfo<CL_CONTEXT_DEVICES>()[0]) << std::endl;
			std::cout << "Build Options:\t" << program.getBuildInfo<CL_PROGRAM_BUILD_OPTIONS>(context.getInfo<CL_CONTEXT_DEVICES>()[0]) << std::endl;
			std::cout << "Build Log:\t " << program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(context.getInfo<CL_CONTEXT_DEVICES>()[0]) << std::endl;
			throw err;
		}

		//vector<string> testReadvec;
		//vector<TemperatureData> data;

		vector<string> placeName;
		vector<int> year;
		vector<int> month;
		vector<int> day;
		vector<string> time;
		vector<float> airTemp;

	

		ReadData::ReadDataIn(&placeName, &year, &month, &day, &time, &airTemp, "temp_lincolnshire.txt");


		int origonalDataSetSize = airTemp.size();
		cout << "Number of teprature items: " << origonalDataSetSize << endl;

		 
		size_t local_size = airTemp.size();
		size_t padding_size = airTemp.size() % local_size;

		//if the input vector is not a multiple of the local_size
		//insert additional neutral elements (0 for addition) so that the total will not be affected
		if (padding_size) {
			//create an extra vector with neutral values
			std::vector<float> A_ext(local_size - padding_size, -1);
			//append that extra vector to our input
			airTemp.insert(airTemp.end(), A_ext.begin(), A_ext.end());
		}

		size_t input_elements = airTemp.size();//number of input elements
		size_t input_size = airTemp.size() * sizeof(float);//size in bytes
		size_t nr_groups = input_elements / local_size;

		//host - output
		std::vector<float> B(local_size);
		size_t output_size = B.size() * sizeof(float);//size in bytes

		

		//device - buffers
		cl::Buffer buffer_A(context, CL_MEM_READ_ONLY, input_size);
		cl::Buffer buffer_B(context, CL_MEM_READ_WRITE, output_size);

		//Part 5 - device operations

		//5.1 Copy arrays A and B to device memory
		queue.enqueueWriteBuffer(buffer_A, CL_TRUE, 0, input_size, &airTemp[0]);
		queue.enqueueFillBuffer(buffer_B, 0, 0, output_size);
		
		

		//5.2 Setup and execute the kernel (i.e. device code)
		cl::Kernel kernel_1 = cl::Kernel(program, "reduce_add_2");
		kernel_1.setArg(0, buffer_A);
		kernel_1.setArg(1, buffer_B);
		//kernel_1.setArg(2, cl::Local(local_size * sizeof(float)));
		//kernel_1.setArg(2, cl::Local(input_size * sizeof(float)));
//		kernel_1.setArg(3, cl::Local(input_size * sizeof(float)));

		cl::Device device = context.getInfo<CL_CONTEXT_DEVICES>()[device_id];//get device
		cerr << "smallest workgroup size suggested: " << kernel_1.getWorkGroupInfo<CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE>(device) << endl;
		cerr << "Maximum work group size: " << kernel_1.getWorkGroupInfo<CL_KERNEL_WORK_GROUP_SIZE>(device) << endl;
		

		float sum = 0;
		for (int i = 0; i < airTemp.size(); i++)
			sum += airTemp[i];
		cout << "Serial sum" <<setprecision(10) <<sum << endl;

		cl::Event profile_Event;
		//call all kernels in a sequence
		queue.enqueueNDRangeKernel(kernel_1, cl::NullRange, cl::NDRange(input_elements), cl::NullRange, NULL, &profile_Event);

		queue.enqueueReadBuffer(buffer_B, CL_TRUE, 0, output_size, &B[0]);

		

		//cout << "A = " << A << endl;
		float val = B[0];
		//cout << B << endl;
		cout << "B = "  <<B[0] << endl;
		cout << "Average = " << B[0] / airTemp.size() << endl;


#pragma region FindMin


		std::vector<float> reduceMinResult(origonalDataSetSize);
		
		cl::Buffer outsortingBuffer(context, CL_MEM_READ_WRITE, input_size);
		cl::Buffer sortingBuffer(context, CL_MEM_READ_ONLY,input_size);
		cl ::Event sortingWriteBufferProfileEvent;
		cl::Event sortingReadBufferProfileEvent;
		cl::Event sortingkernalProfileEvent;


		//cout << airTemp << endl;

		queue.enqueueWriteBuffer(sortingBuffer, CL_TRUE, 0, input_size, &airTemp[0],NULL, &sortingWriteBufferProfileEvent);
		//queue.enqueueFillBuffer(buffer_B, 0, 0, input_size);

		std::cout << "Buffer Writing time: [ns] " << sortingWriteBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_END>()
			- sortingWriteBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_START>() << std::endl;

		std::cout << "Full profile info" << GetFullProfilingInfo(sortingWriteBufferProfileEvent, ProfilingResolution::PROF_US) << std::endl;


		cl::Kernel sortingKernel = cl::Kernel(program,"calculateMin");
		sortingKernel.setArg(0, sortingBuffer);
		sortingKernel.setArg(1, outsortingBuffer);

		//QUE KERNEL
		queue.enqueueNDRangeKernel(sortingKernel, cl::NullRange, cl::NDRange(input_elements), cl::NullRange, NULL, &sortingkernalProfileEvent);

		std::cout << "Find MIN Kernel execution time [ns] " << sortingkernalProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_END>()
			- sortingkernalProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_START>() << std::endl;

		std::cout << "Full profile info" << GetFullProfilingInfo(sortingkernalProfileEvent, ProfilingResolution::PROF_US) << std::endl;


		//READ BUFFER
		queue.enqueueReadBuffer(outsortingBuffer, CL_TRUE, 0, input_size, &reduceMinResult[0],NULL, &sortingReadBufferProfileEvent);
	

		std::cout << "Buuffer Reading time [ns] " << sortingReadBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_END>()
			- sortingReadBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_START>() << std::endl;

		std::cout << "Full profile info" << GetFullProfilingInfo(sortingReadBufferProfileEvent, ProfilingResolution::PROF_US) << std::endl;

	//	cout << sortedTmps << endl;



		cout << "Minimum Value: " << reduceMinResult[0] << endl;


#pragma endregion


		float minVal = airTemp[0];
		for (int i = 0; i < airTemp.size(); i++)
			if (airTemp[i] < minVal)
				minVal = airTemp[i];
		cout << "Serial Find Min" << minVal << endl;


#pragma region FindMax
		std::vector<float> reduceMaxResult(origonalDataSetSize);

		cl::Kernel findMaxKernal = cl::Kernel(program, "calculateMax");
		findMaxKernal.setArg(0, sortingBuffer);
		findMaxKernal.setArg(1, outsortingBuffer);

		//QuE min kernel
		queue.enqueueNDRangeKernel(findMaxKernal, cl::NullRange, cl::NDRange(input_elements), cl::NullRange, NULL, &sortingkernalProfileEvent);

		std::cout << "Find Max Kernel execution time [ns] " << sortingkernalProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_END>()
			- sortingkernalProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_START>() << std::endl;

		std::cout << "Full profile info" << GetFullProfilingInfo(sortingkernalProfileEvent, ProfilingResolution::PROF_US) << std::endl;

		//READ BUFFER
		queue.enqueueReadBuffer(outsortingBuffer, CL_TRUE, 0, input_size, &reduceMaxResult[0], NULL, &sortingReadBufferProfileEvent);


		std::cout << "Buuffer Reading time [ns] " << sortingReadBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_END>()
			- sortingReadBufferProfileEvent.getProfilingInfo<CL_PROFILING_COMMAND_START>() << std::endl;

		std::cout << "Full profile info" << GetFullProfilingInfo(sortingReadBufferProfileEvent, ProfilingResolution::PROF_US) << std::endl;

		//	cout << sortedTmps << endl;

		/*for (int i = 0; i < origonalDataSetSize; i++)
			cout << "Val " << reduceMaxResult[i] << endl;*/

		cout << "Maximum Value: " << reduceMaxResult[0] << endl;

#pragma endregion



		float maxVal = airTemp[0];
		for (int i = 0; i < airTemp.size(); i++)
			if(airTemp[i] > maxVal)
			maxVal = airTemp[i];
		cout << "Serial Find Max" << maxVal << endl;

		int nbrBins = 6;

		std::vector<int> histBins(nbrBins);

		cl::Buffer nbBins(context, CL_MEM_READ_WRITE, sizeof(int));
		cl::Buffer outBuffer(context, CL_MEM_READ_WRITE, nbrBins* sizeof(int));
		//cl::Buffer buffer_C(context, CL_MEM_READ_ONLY, sizeof(numBins));
		//Part 5 - device operations

		
		queue.enqueueWriteBuffer(nbBins, CL_TRUE, 0, 1, &nbrBins);
		queue.enqueueFillBuffer(outBuffer, 0, 0, nbrBins);//zero B buffer on


		cl::Kernel histGramKernel = cl::Kernel(program,"hist_simple");
		histGramKernel.setArg(0, buffer_A);
		histGramKernel.setArg(1, outBuffer);
		//kernel_1.setArg(2, nbBins);

		queue.enqueueNDRangeKernel(histGramKernel, cl::NullRange, cl::NDRange(input_elements), cl::NullRange);

		queue.enqueueReadBuffer(outBuffer, CL_TRUE, 0, nbrBins, &histBins[0]);

		cout <<"Hist Bins: " << histBins << endl;
	}
	catch (cl::Error err) {
		cerr << "ERROR: " << err.what() << ", " << getErrorString(err.err()) << endl;
	}

	cin.get();

	return 0;
}