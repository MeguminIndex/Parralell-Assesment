
__kernel void calculateMin()
{

}


__kernel void calculateMax()
{

}

__kernel void calculateAverage()
{



}


//flexible step reduce 
__kernel void reduce_add_2(__global const float* A, __global float* B) {
	int id = get_global_id(0);
	int N = get_global_size(0);

	B[id] = A[id];

	barrier(CLK_GLOBAL_MEM_FENCE);

	for (int i = 1; i < N; i *= 2) { //i is a stride
		if (!(id % (i * 2)) && ((id + i) < N))
			B[id] += B[id + i];

		//printf("id: %d Sum = %f\n",id,B[id]);
		barrier(CLK_GLOBAL_MEM_FENCE);
	}
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
__kernel void reduce_add_4(__global const int* A, __global int* B, __local int* scratch) {
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

	//we add results from all local groups to the first element of the array
	//serial operation! but works for any group size
	//copy the cache to output array
	if (!lid) {
		atomic_add(&B[0], scratch[lid]);
	}
}


//a double-buffered version of the Hillis-Steele inclusive scan
//requires two additional input arguments which correspond to two local buffers
__kernel void scan_add(__global const int* A, __global int* B, __local int* scratch_1, __local int* scratch_2) {
	int id = get_global_id(0);
	int lid = get_local_id(0);
	int N = get_local_size(0);
	__local int *scratch_3;//used for buffer swap

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



void cmpxchg(__global float* A, __global float* B) {
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
				cmpxchg(&A[id], &A[id + 1]);//call compare function
			}
			

			barrier(CLK_GLOBAL_MEM_FENCE);


			if (id % 2 == 0 && id + 1 < N) { //even
				cmpxchg(&A[id], &A[id + 1]);
			
				}

			barrier(CLK_GLOBAL_MEM_FENCE);


			}

		
		
	

		//barrier(CLK_GLOBAL_MEM_FENCE);

		//if (id == 1)
		//{
		//	for(int i=0; i < 10; i++)
		//	printf("ind %d : %f \n ",i,A[i]);
		//}

}


