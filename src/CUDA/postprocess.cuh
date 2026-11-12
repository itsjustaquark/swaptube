#include <cuda_runtime.h>
#include "../Host_Device_Shared/vec.h"

/*__global__ static void postprocess_kernel(const Cuda::ivec2& wh_in,
    unsigned int* frame_in
){
    int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
    int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;

    frame_in[pixel_y * wh_in.x + pixel_x] = 0xffffffff;
}*/

__global__ static void post_rescale_kernel(const int wh_in_x, const int wh_in_y, const int wh_out_x, const int wh_out_y,
    unsigned int* frame_in, unsigned int* frame_out
){
    int out_pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
    int out_pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
    
    Cuda::ivec2 wh_in(wh_in_x, wh_in_y);
    Cuda::ivec2 wh_out(wh_out_x, wh_out_y);

    if (out_pixel_x >= wh_out.x || out_pixel_y >= wh_out.y) return;

    const Cuda::ivec2 downsample_ratio = wh_in / wh_out;

    // Only integer downsampling for now
    if(wh_out.x > wh_in.x || wh_out.y > wh_in.y || wh_in.x % wh_out.x != 0 || wh_in.y % wh_out.y != 0 || downsample_ratio.x != downsample_ratio.y){
        frame_out[out_pixel_y * wh_in.x + out_pixel_x] = 0x00000000;
        return;
    }

    int in_pixel_x = out_pixel_x * downsample_ratio.x;
    int in_pixel_y = out_pixel_y * downsample_ratio.y;

    unsigned int a_sum = 0;
    unsigned int r_sum = 0;
    unsigned int g_sum = 0;
    unsigned int b_sum = 0;

    for(int i = 0; i < downsample_ratio.x; i++){
        for(int j = 0; j < downsample_ratio.y; j++){
            unsigned int pixel = frame_in[(in_pixel_y + j) * wh_in.x + (in_pixel_x + i)];
            a_sum += (pixel >> 24) & 0xff;
            r_sum += (pixel >> 16) & 0xff;
            g_sum += (pixel >> 8) & 0xff;
            b_sum += (pixel) & 0xff;
        }
    }

    int dimensions = downsample_ratio.x * downsample_ratio.y;

    a_sum /= dimensions;
    r_sum /= dimensions;
    g_sum /= dimensions;
    b_sum /= dimensions;

    unsigned int color_out = (a_sum << 24) | (r_sum << 16) | (g_sum << 8) | (b_sum);

    frame_out[out_pixel_y * wh_out.x + out_pixel_x] = color_out;
}

__host__ static void postprocess_frame(
    const Cuda::ivec2& wh_in, const Cuda::ivec2& wh_out,
    unsigned int* frame_in, unsigned int* frame_out
) {
    // Define grid and block dimensions
    dim3 threadsPerBlock(16, 16);  // 2D block of 16x16 threads
    dim3 numBlocks((wh_in.x + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (wh_in.y + threadsPerBlock.y - 1) / threadsPerBlock.y);

    // Launch the kernel
    /*postprocess_kernel<<<numBlocks, threadsPerBlock>>>(
        wh_in,
        frame_in;
    );*/
    
    // Redefine block dimensions
    numBlocks = dim3((wh_out.x + threadsPerBlock.x - 1) / threadsPerBlock.x,
                   (wh_out.y + threadsPerBlock.y - 1) / threadsPerBlock.y);

    post_rescale_kernel<<<numBlocks, threadsPerBlock>>>(
        wh_in.x, wh_in.y, wh_out.x, wh_out.y,
        frame_in, frame_out
    );
}