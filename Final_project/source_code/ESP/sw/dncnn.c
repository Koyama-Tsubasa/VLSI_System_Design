/* Copyright (c) 2011-2021 Columbia University, System Level Design Group */
/* SPDX-License-Identifier: Apache-2.0 */

#include <stdio.h>
#ifndef __riscv
#include <stdlib.h>
#endif

#include <esp_accelerator.h>
#include <esp_probe.h>
#include <fixed_point.h>

#include "pattern/weight.h"
#include "pattern/golden00.h"
#include "pattern/image00.h"

typedef int32_t token_t;

// static unsigned DMA_WORD_PER_BEAT(unsigned _st)
// {
//         return (sizeof(void *) / _st);
// }


#define SLD_DNCNN 0x0ac
#define DEV_NAME "sld,dncnn_rtl"

/* <<--params-->> */

//======================================
// TODO
// Modify these quantization scale to we provided.
const int32_t Conv3_scale =  81;
const int32_t Conv2_scale = 119;
const int32_t Conv1_scale = 149;
const int32_t Conv7_scale = 225;
const int32_t Conv6_scale = 279;
const int32_t Conv5_scale = 184;
const int32_t Conv4_scale = 157;
//======================================

// static unsigned in_words_adj;
// static unsigned out_words_adj;
// static unsigned in_len;
// static unsigned out_len;
// static unsigned in_size;
// static unsigned out_size;
// static unsigned out_offset;
// static unsigned mem_size;

static unsigned mem_size;
token_t *mem;

/* Size of the contiguous chunks for scatter/gather */
#define CHUNK_SHIFT 20
#define CHUNK_SIZE BIT(CHUNK_SHIFT)
#define NCHUNK(_sz) ((_sz % CHUNK_SIZE == 0) ?		\
			(_sz / CHUNK_SIZE) :		\
			(_sz / CHUNK_SIZE) + 1)

/* User defined registers */
/* <<--regs-->> */
#define DNCNN_CONV5_SCALE_REG 0x58
#define DNCNN_CONV1_SCALE_REG 0x54
#define DNCNN_CONV6_SCALE_REG 0x50
#define DNCNN_CONV3_SCALE_REG 0x4c
#define DNCNN_CONV2_SCALE_REG 0x48
#define DNCNN_CONV7_SCALE_REG 0x44
#define DNCNN_CONV4_SCALE_REG 0x40


static int validate_buf()
{
	// int i;
	// int j;
	// unsigned errors = 0;

	// for (i = 0; i < 1; i++)
	// 	for (j = 0; j < Conv4_scale; j++)
	// 		if (gold[i * out_words_adj + j] != out[i * out_words_adj + j])
	// 			errors++;

	// return errors;

	int i, j;
	int errors = 0;
	int total_errors = 0;
	
	// image
	for(i = 0 ; i < 256 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Image pass!\n");
	else
		printf("===> Image fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv1
	for(i = 256 ; i < 4352 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-256, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv1 pass!\n");
	else
		printf("===> Conv1 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv2
	for(i = 4352 ; i < 8448 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-4352, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv2 pass!\n");
	else
		printf("===> Conv2 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv3
	for(i = 8448 ; i < 12544 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-8448, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv3 pass!\n");
	else
		printf("===> Conv3 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv4
	for(i = 12544 ; i < 16640 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-12544, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv4 pass!\n");
	else
		printf("===> Conv4 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv5
	for(i = 16640 ; i < 20736 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-16640, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv5 pass!\n");
	else
		printf("===> Conv5 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv6
	for(i = 20736 ; i < 24832 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-20736, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv6 pass!\n");
	else
		printf("===> Conv6 fail!\n");
	total_errors += errors;
	errors = 0;

	// Conv7
	for(i = 24832 ; i < 25088 ; i++){
		if(mem[4000+i] != golden[i]){
			printf("[ERROR]: index %d, result:%8x, gold:%8x\n", i-24832, mem[4000+i], golden[i]);
			errors++;
		}
		else{
			
			// printf("[CORRECT]: index %d, result:%8x, gold:%8x\n", i, mem[4000+i], golden[i]);
		}
	}
	if(errors == 0)
		printf("===> Conv7 pass!\n");
	else
		printf("===> Conv7 fail!\n");
	total_errors += errors;

	return total_errors;
}


static void init_buf ()
{
	// int i;
	// int j;

	// for (i = 0; i < 1; i++)
	// 	for (j = 0; j < Conv4_scale; j++)
	// 		in[i * in_words_adj + j] = (token_t) j;

	// for (i = 0; i < 1; i++)
	// 	for (j = 0; j < Conv4_scale; j++)
	// 		gold[i * out_words_adj + j] = (token_t) j;

	// Weight
	int i, j;
	for(i = 0 ; i < 3936 ; i++){
		mem[i] = weight[i];
	}
	// Image
	for(i = 0 ; i < 256 ; i++){
		mem[4000+i] = image[i];
	}
}

// static inline uint64_t get_counter()
// {
// 	uint64_t counter;
// 	asm volatile (
// 		"li t0, 0;"
// 		"csrr t0, mcycle;"
// 		"mv %0, t0"
// 		: "=r" ( counter )
// 		:
// 		: "t0"
// 	);
// 	return counter;
// }


// static void compute_dncnn()
// {
// 	int N = 1, C, R = 3, S = 3, M, P, Q;
// 	int i, j, k, l, n, c, h, w, r, s, m, p, q;
// 	float image[34][34] = {
// 	    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0},
// 	    {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
// 	};
// 	float weight_conv1[16][1][3][3];
// 	float conv1[16][34][34] = {0};
// 	float weight_conv2[16][16][3][3];
// 	float conv2[16][34][34] = {0};
// 	float weight_conv3[16][16][3][3];
// 	float conv3[16][34][34] = {0};
// 	float weight_conv4[16][16][3][3];
// 	float conv4[16][34][34] = {0};
// 	float weight_conv5[16][16][3][3];
// 	float conv5[16][34][34] = {0};
// 	float weight_conv6[16][16][3][3];
// 	float conv6[16][34][34] = {0};
// 	float weight_conv7[16][1][3][3];
// 	float conv7[32][32] = {0};
	
// 	for (i=0;i<16;i++) {
// 	    for (j=0;j<16;j++) {
// 	        for (k=0;k<3;k++) {
// 	            for (l=0;l<3;l++) {
// 	                if (j==0) {
// 	                    weight_conv1[i][j][k][l] = 1;
// 	                    weight_conv7[i][j][k][l] = 7;
// 	                }
// 	                weight_conv2[i][j][k][l] = 2;
// 	                weight_conv3[i][j][k][l] = 3;
// 	                weight_conv4[i][j][k][l] = 4;
// 	                weight_conv5[i][j][k][l] = 5;
// 	                weight_conv6[i][j][k][l] = 6;
// 	            }
// 	        }
// 	    }
// 	}

// 	for (i=0; i<7; i++) {

// 		switch(i) {
// 			case 0:
// 				C = 1;
// 				M = 16;
// 				P = 34;
// 				Q = 34;
// 				break;
// 			case 6:
// 				C = 16;
// 				M = 1;
// 				P = 32;
// 				Q = 32;
// 				break;
// 			default:
// 				C = 16;
// 				M = 16;
// 				P = 34;
// 				Q = 34;
// 		}
//         // printf("Conv_%d: %d, %d, %d, %d, %d, %d, %d\n", i+1, N, C, R, S, M, P, Q);
// 		for (n=0; n<N; n++) {
// 			for (m=0; m<M; m++) {
// 				for (p=0; p<P; p++) {
// 					if (i!=6 && (p==0 || p==33)) continue;
// 					for (q=0; q<Q; q++) {
// 						if (i!=6 && (q==0 || q==33)) continue;
// 						for (r=0; r<R; r++) {
// 							for (s=0; s<S; s++) {
// 								for (c=0; c<C; c++) {
// 									h = p + r;
// 									w = q + s;
// 									if (i==0) conv1[m][p][q] += image[h][w]*weight_conv1[m][c][r][s];
// 									else if (i==1) conv2[m][p][q] += conv1[c][p][q]*weight_conv2[m][c][r][s];
// 									else if (i==2) conv3[m][p][q] += conv2[c][p][q]*weight_conv3[m][c][r][s];
// 									else if (i==3) conv4[m][p][q] += conv3[c][p][q]*weight_conv4[m][c][r][s];
// 									else if (i==4) conv5[m][p][q] += conv4[c][p][q]*weight_conv5[m][c][r][s];
// 									else if (i==5) conv6[m][p][q] += conv5[c][p][q]*weight_conv6[m][c][r][s];
// 									else conv7[p][q] += conv6[c][p][q]*weight_conv7[m][c][r][s];
// 								}
// 							}
// 						}
// 						if (i==0) conv1[m][p][q] = conv1[m][p][q]>=0 ? conv1[m][p][q] : 0 ;
// 						else if (i==1) conv2[m][p][q] = conv2[m][p][q]>=0 ? conv2[m][p][q] : 0 ;
// 						else if (i==2) conv3[m][p][q] = conv3[m][p][q]>=0 ? conv3[m][p][q] : 0 ;
// 						else if (i==3) conv4[m][p][q] = conv4[m][p][q]>=0 ? conv4[m][p][q] : 0 ;
// 						else if (i==4) conv5[m][p][q] = conv5[m][p][q]>=0 ? conv5[m][p][q] : 0 ;
// 						else if (i==5) conv6[m][p][q] = conv6[m][p][q]>=0 ? conv6[m][p][q] : 0 ;
// 						else conv7[p][q] = conv7[p][q]>=0 ? conv7[p][q] : 0 ;
// 					}
// 				}
// 			}
// 		}

// 	}
// }


int main(int argc, char * argv[])
{
	int i;
	int n;
	int ndev;
	struct esp_device *espdevs;
	struct esp_device *dev;
	unsigned done;
	unsigned **ptable;
	// token_t *mem;
	// token_t *gold;
	unsigned errors = 0;
	unsigned coherence;

	// if (DMA_WORD_PER_BEAT(sizeof(token_t)) == 0) {
	// 	in_words_adj = Conv4_scale;
	// 	out_words_adj = Conv4_scale;
	// } else {
	// 	in_words_adj = round_up(Conv4_scale, DMA_WORD_PER_BEAT(sizeof(token_t)));
	// 	out_words_adj = round_up(Conv4_scale, DMA_WORD_PER_BEAT(sizeof(token_t)));
	// }
	// in_len = in_words_adj * (1);
	// out_len = out_words_adj * (1);
	// in_size = in_len * sizeof(token_t);
	// out_size = out_len * sizeof(token_t);
	// out_offset  = in_len;
	// mem_size = (out_offset * sizeof(token_t)) + out_size;

	// uint64_t start_time = get_counter();
	// compute_dncnn();
	// uint64_t finish_time = get_counter();
	// uint64_t compute_time = finish_time - start_time;
	// printf("DnCNN[C]: %d cycles\n", compute_time);

	// calculate compute_time outside first
	// === code ===
	// start = clock()
	// compute_dncnn()
	// end =clock()
	// run 10 times and calculate average time
	double compute_time, ps_per_cycle, micros_per_cycle;
	compute_time = 131256;						// micro s (10^-6)
	printf("DnCNN[C]_compute_time: %ld micro sec\n", (long)compute_time);
	ps_per_cycle = 42949526400/1147457;			// ps_per_cycle	(10^-12)
	micros_per_cycle = ps_per_cycle/1000000;	// micros_per_cycle in esp
	printf("ps per cycle in ESP: %ld ps\n", (long)ps_per_cycle);
	printf("DnCNN[C]_cycles: %ld cycles\n", (long)(compute_time/micros_per_cycle));


	// Define DRAM size, please refer to spec to know the lease size.
	mem_size = 40000*sizeof(token_t);

	// Search for the device
	printf("Scanning device tree... \n");

	ndev = probe(&espdevs, VENDOR_SLD, SLD_DNCNN, DEV_NAME);
	if (ndev == 0) {
		printf("dncnn not found\n");
		return 0;
	}

	for (n = 0; n < ndev; n++) {

		printf("**************** %s.%d ****************\n", DEV_NAME, n);

		dev = &espdevs[n];

		// Check DMA capabilities
		if (ioread32(dev, PT_NCHUNK_MAX_REG) == 0) {
			printf("  -> scatter-gather DMA is disabled. Abort.\n");
			return 0;
		}

		if (ioread32(dev, PT_NCHUNK_MAX_REG) < NCHUNK(mem_size)) {
			printf("  -> Not enough TLB entries available. Abort.\n");
			return 0;
		}

		// Allocate memory
		// gold = aligned_malloc(out_size);
		mem = aligned_malloc(mem_size);
		printf("  memory buffer base-address = %p\n", mem);

		// Alocate and populate page table
		ptable = aligned_malloc(NCHUNK(mem_size) * sizeof(unsigned *));
		for (i = 0; i < NCHUNK(mem_size); i++)
			ptable[i] = (unsigned *) &mem[i * (CHUNK_SIZE / sizeof(token_t))];

		printf("  ptable = %p\n", ptable);
		printf("  nchunk = %lu\n", NCHUNK(mem_size));

#ifndef __riscv
		for (coherence = ACC_COH_NONE; coherence <= ACC_COH_RECALL; coherence++) {
#else
		{
			/* TODO: Restore full test once ESP caches are integrated */
			coherence = ACC_COH_NONE;
#endif
			printf("  --------------------\n");
			printf("  Generate input...\n");
			// init_buf(mem, gold);
			init_buf();

			// Pass common configuration parameters

			iowrite32(dev, SELECT_REG, ioread32(dev, DEVID_REG));
			iowrite32(dev, COHERENCE_REG, coherence);

#ifndef __sparc
			iowrite32(dev, PT_ADDRESS_REG, (unsigned long long) ptable);
#else
			iowrite32(dev, PT_ADDRESS_REG, (unsigned) ptable);
#endif
			iowrite32(dev, PT_NCHUNK_REG, NCHUNK(mem_size));
			iowrite32(dev, PT_SHIFT_REG, CHUNK_SHIFT);

			// Use the following if input and output data are not allocated at the default offsets
			iowrite32(dev, SRC_OFFSET_REG, 0x0);
			iowrite32(dev, DST_OFFSET_REG, 0x0);

			// Pass accelerator-specific configuration parameters
			/* <<--regs-config-->> */
			iowrite32(dev, DNCNN_CONV3_SCALE_REG, Conv3_scale);
			iowrite32(dev, DNCNN_CONV2_SCALE_REG, Conv2_scale);
			iowrite32(dev, DNCNN_CONV1_SCALE_REG, Conv1_scale);
			iowrite32(dev, DNCNN_CONV7_SCALE_REG, Conv7_scale);
			iowrite32(dev, DNCNN_CONV6_SCALE_REG, Conv6_scale);
			iowrite32(dev, DNCNN_CONV5_SCALE_REG, Conv5_scale);
			iowrite32(dev, DNCNN_CONV4_SCALE_REG, Conv4_scale);

			// Flush (customize coherence model here)
			esp_flush(coherence);

			// Start accelerators
			printf("  Start...\n");
			iowrite32(dev, CMD_REG, CMD_MASK_START);

			// Wait for completion
			done = 0;
			while (!done) {
				done = ioread32(dev, STATUS_REG);
				done &= STATUS_MASK_DONE;
			}
			iowrite32(dev, CMD_REG, 0x0);

			printf("  Done\n");
			printf("  validating...\n");

			/* Validation */
			// errors = validate_buf(&mem[out_offset], gold);
			errors = validate_buf();
			if (errors)
				printf("[FAIL] There are some errors QQ\n");
			else
				printf("[PASS] Congratulation! All results are correct\n");
		}
		aligned_free(ptable);
		aligned_free(mem);
		// aligned_free(gold);
	}

	return 0;
}
