

//Function to perform the atomic max

//Create a union of float and int so math can be performed on the float but used intergers for the atomic exchange
inline void AtomicMax(volatile __global float *source, const float operand) {
	union {
		unsigned int intVal;
		float floatVal;
	} newVal;
	union {
		unsigned int intVal;
		float floatVal;
	} prevVal;
	//do while to serilize memory acces like the traditional atomic functions for ints
	do {
		prevVal.floatVal = *source;
		newVal.floatVal = max(prevVal.floatVal, operand);
	} while (atomic_cmpxchg((volatile __global unsigned int *)source, prevVal.intVal, newVal.intVal) != prevVal.intVal);
}

//Function to perform the atomic Min
inline void AtomicMin(volatile __global float *source, const float operand) {
	union {
		unsigned int intVal;
		float floatVal;
	} newVal;
	union {
		unsigned int intVal;
		float floatVal;
	} prevVal;
	do {
		prevVal.floatVal = *source;
		newVal.floatVal = min(prevVal.floatVal, operand);
	} while (atomic_cmpxchg((volatile __global unsigned int *)source, prevVal.intVal, newVal.intVal) != prevVal.intVal);
}


//Origonal source for add function was found here: http://suhorukov.blogspot.co.uk/2011/12/opencl-11-atomic-operations-on-floating.html
inline void AtomicAdd(volatile __global float *source, const float operand) {
	union {
		unsigned int intVal;
		float floatVal;
	} newVal;
	union {
		unsigned int intVal;
		float floatVal;
	} prevVal;
	do {
		prevVal.floatVal = *source;
		newVal.floatVal = prevVal.floatVal + operand;
	} while (atomic_cmpxchg((volatile __global unsigned int *)source, prevVal.intVal, newVal.intVal) != prevVal.intVal);
}



__kernel void calculateMax(__global const float* input, __global float* output)
{

	int id = get_global_id(0);
	int N = get_global_size(0);
	if (id == 1)
		printf("Calc Max global size %d \n\n ", N);
	////output[id] = input[id];

	output[id] = input[id];

	float maxV;

	barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		
		if (((id + i) < N))
		{
			//if (output[id + i] > output[id])
			//{
				//output[id] = output[id + i];
			if (maxV < output[id + i])
				maxV = output[id + i];
			// printf("ID %d  Val: %f \n",id, output[id]);

		//}
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	}




	AtomicMax(output, maxV);

	

}



__kernel void calculateMin(__global const float* input, __global float* output)
{
	int id = get_global_id(0);
	int N = get_global_size(0);
	if (id == 1)
		printf("Calc Min global size %d \n\n ", N);

	output[id] = input[id];

	float minV;

	barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		if (((id + i) < N))
		{
			// if (output[id + i] < output[id])
			//{
			//  output[id] = output[id + i];
			// printf("ID %d  Val: %f \n",id, output[id]);
			if (minV > output[id + i])
				minV = output[id + i];

			//}
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	}

	AtomicMin(output, minV);

}



//flexible step reduce 
__kernel void reduce_add_2(__global const float* A, __global float* B) {
	int id = get_global_id(0);
	int N = get_global_size(0);


	B[id] = A[id];

	barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		if (!(id % (i * 2)) && ((id + i) < N))
		{
			B[id] += B[id + i];

			//AtomicAdd(&B[id], B[id+i]);
			//printf("id: %d Sum = %f\n",id,B[id]);
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	}

	//AtomicAdd(&B[0], B[id]);
}




//reduce using local memory (so called privatisation)
__kernel void reduce_add_3(__global const int* A, __global int* B, __local int* scratch) {
	int id = get_global_id(0);
	int lid = get_local_id(0);
	int N = get_local_size(0);

	//cache all N values from global memory to local memory
	scratch[lid] = A[id];

	barrier(CLK_LOCAL_MEM_FENCE);//wait for all local threads to finish copying from global to local memory

	for (int i = 1; i < N; i *= 2) {
		if (!(lid % (i * 2)) && ((lid + i) < N))
			scratch[lid] += scratch[lid + i];

		barrier(CLK_LOCAL_MEM_FENCE);
	}

	//copy the cache to output array
	B[id] = scratch[lid];
}

//reduce using local memory + accumulation of local sums into a single location
//works with any number of groups - not optimal!
__kernel void reduce_add_4(__global const float* A, __global float* B, __local float* scratch) {
	int id = get_global_id(0);
	int lid = get_local_id(0);
	int N = get_local_size(0);

	//cache all N values from global memory to local memory
	scratch[lid] = A[id];

	barrier(CLK_LOCAL_MEM_FENCE);//wait for all local threads to finish copying from global to local memory

	for (int i = 1; i < N; i *= 2) {
		if (!(lid % (i * 2)) && ((lid + i) < N))
			scratch[lid] += scratch[lid + i];

		barrier(CLK_LOCAL_MEM_FENCE);
	}

	// Write result to partialSums [nWorkGroups]
	if (lid == 0)
		B[get_group_id(0)] = scratch[0];



	////we add results from all local groups to the first element of the array
	////serial operation! but works for any group size
	////copy the cache to output array
	//if (!lid) {
	//	atomic_add(&B[0], scratch[lid]);
	//}
}


//a double-buffered version of the Hillis-Steele inclusive scan
//requires two additional input arguments which correspond to two local buffers
__kernel void scan_add(__global const float* A, __global float* B, __local float* scratch_1, __local float* scratch_2) {
	int id = get_global_id(0);
	int lid = get_local_id(0);
	int N = get_local_size(0);
	__local float *scratch_3;//used for buffer swap

						   //cache all N values from global memory to local memory
	scratch_1[lid] = A[id];

	barrier(CLK_LOCAL_MEM_FENCE);//wait for all local threads to finish copying from global to local memory

	for (int i = 1; i < N; i *= 2) {
		if (lid >= i)
			scratch_2[lid] = scratch_1[lid] + scratch_1[lid - i];
		else
			scratch_2[lid] = scratch_1[lid];

		barrier(CLK_LOCAL_MEM_FENCE);

		//buffer swap
		scratch_3 = scratch_2;
		scratch_2 = scratch_1;
		scratch_1 = scratch_3;
	}

	//copy the cache to output array
	B[id] = scratch_1[lid];
}



void compareBubble(__global float* A, __global float* B) {
	//check values 
	if (*A > *B) {
		float t = *A; *A = *B; *B = t;
	}
}

__kernel void BubbleSort(__global float* A)
{
	int id = get_global_id(0);
	int N = get_global_size(0);
	if(id == 1)
		printf("ind %d \n ", N);

		for (int i = 0; i < N; i += 2)
		{
			if (id % 2 == 1 && id + 1 < N)//ODD 
			{
				compareBubble(&A[id], &A[id + 1]);//call compare function
			}
			

			barrier(CLK_GLOBAL_MEM_FENCE);


			if (id % 2 == 0 && id + 1 < N) { //even
				compareBubble(&A[id], &A[id + 1]);
			
				}

			barrier(CLK_GLOBAL_MEM_FENCE);


			}
}




__kernel void hist_simple(__global const float* A, __global int* H) {
	int id = get_global_id(0);

	
	float bin_index = A[id];//take value as a bin index#
	int index = -1;

	if (bin_index < -20)
		index = 0;
	else if (bin_index < -10)
		index = 1;
	else if (bin_index < 0)
		index = 2;
	else if (bin_index < 10)
		index = 3;
	else if (bin_index < 20)
		index = 4;
	else
		index = 5;
	

	

	if (index != -1)
		atomic_inc(&H[index]);//serial operation, not very efficient!


}