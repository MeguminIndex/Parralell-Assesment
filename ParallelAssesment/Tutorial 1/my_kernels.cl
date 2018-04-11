

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

	output[id] = input[id];

	float minV;

	barrier(CLK_GLOBAL_MEM_FENCE);

	for ( int i = 1; i < N; i *= 2) { //i is a stride
		if (((id + i) < N))
		{
			// if (output[id + i] < output[id])
			//{
			  //output[id] = output[id + i];
			// printf("ID %d  Val: %f \n",id, output[id]);
			if (minV > output[id + i])
				minV = output[id + i];

		//}
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	}

	AtomicMin(output, minV);

}


__kernel void SumADD(__global const float *input, __global float *output, __local float* scratch)
{
	int id = get_global_id(0);
	int N = get_global_size(0);
	int lN = get_local_size(0);
	int tid = get_local_id(0);

	scratch[tid] = input[id];

	barrier(CLK_LOCAL_MEM_FENCE);

	
	
	if (tid == 0)
	{
		for (int i = 0; i < lN; i++)
		{
			if(scratch[tid + i] < lN)
			scratch[tid] += scratch[tid + i];
		}
	}

	barrier(CLK_GLOBAL_MEM_FENCE);
	barrier(CLK_LOCAL_MEM_FENCE);

	if(tid == 0)
	output[id] = scratch[tid];


}


__kernel void reduce_add(__global const float* A, __global float* B, __local float* scratch) {
	int id = get_global_id(0);
	int N = get_global_size(0);
	int lN = get_local_size(0);
	int tid = get_local_id(0);

	scratch[tid] = A[id];

	barrier(CLK_LOCAL_MEM_FENCE);

	for (unsigned int i = 1; i < lN; i *= 2) {
		if (tid % (2 * i) == 0 && ((tid + i) < lN))
		{
			scratch[tid] += scratch[tid + i];


			//printf("id: %d Sum = %f\n",id,B[id]);
		}
		barrier(CLK_LOCAL_MEM_FENCE);
	}

	 B[id] = scratch[tid];

}

__kernel void reduce_add_2(__global const float* A, __global float* B) {
	int id = get_global_id(0);
	int N = get_global_size(0);


	B[id] = A[id];

	barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		if (!(id % (i * 2)) && ((id + i) < N))
		{
			B[id] += B[id + i];

			

			//printf("id: %d Sum = %f\n",id,B[id]);
		}
		barrier(CLK_GLOBAL_MEM_FENCE);
	}
}

__kernel void MyReduce(__global const float* A, __global float* B) {
	int id = get_global_id(0);
	int N = get_global_size(0);



	//B[id] = A[id];

	//private for each work item
	__private float val;

	//barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		if (!(id % (i * 2)) && ((id + i) < N))
		{	
			val += A[id + i];	
		}
		//barrier(CLK_GLOBAL_MEM_FENCE);
	}

	barrier(CLK_GLOBAL_MEM_FENCE);

	AtomicAdd(&B[0], val);
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
	int N = get_global_size(0);

		//move value to private memory for quick acces since we could be checkin this several time depending which condition it meets
		float bin_index = A[id];//take value as a bin index#

		int index = -1;


		//harcoded bin values - improvement would to be pass in an array of values to defince the ranges along with the number of bins
		if (bin_index < -20.0f)
			index = 0;
		else if (bin_index < -10.0f)
			index = 1;
		else if (bin_index < 0.0f)
			index = 2;
		else if (bin_index < 10.0f)
			index = 3;
		else if (bin_index < 20.0f)
			index = 4;
		else
			index = 5;





		atomic_inc(&H[index]);//serial operation, not very efficient!

	

}