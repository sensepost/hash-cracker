/**
 * Author......: Jens Steube <jens.steube@gmail.com>
 * License.....: MIT
 */

#ifndef CPU_RULES_H
#define CPU_RULES_H

#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>
#include "rp_cpu.h"

#define BLOCK_SIZE               64
#define RULE_RC_REJECT_ERROR     -2
#define RP_RULE_BUFSIZ        0x100
#define RULE_RC_SYNTAX_ERROR     -1

typedef unsigned int uint;

typedef struct
{
  uint cmds[32];

} gpu_rule_t;

int mangle_lrest (char arr[BLOCK_SIZE], int arr_len);
int mangle_urest (char arr[BLOCK_SIZE], int arr_len);
int mangle_trest (char arr[BLOCK_SIZE], int arr_len);
int mangle_reverse (char arr[BLOCK_SIZE], int arr_len);
int mangle_double (char arr[BLOCK_SIZE], int arr_len);
int mangle_double_times (char arr[BLOCK_SIZE], int arr_len, int times);
int mangle_reflect (char arr[BLOCK_SIZE], int arr_len);
int mangle_rotate_left (char arr[BLOCK_SIZE], int arr_len);
int mangle_rotate_right (char arr[BLOCK_SIZE], int arr_len);
int mangle_append (char arr[BLOCK_SIZE], int arr_len, char c);
int mangle_prepend (char arr[BLOCK_SIZE], int arr_len, char c);
int mangle_delete_at (char arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_extract (char arr[BLOCK_SIZE], int arr_len, int upos, int ulen);
int mangle_omit (char arr[BLOCK_SIZE], int arr_len, int upos, int ulen);
int mangle_insert (char arr[BLOCK_SIZE], int arr_len, int upos, char c);
int mangle_insert_multi (char arr[BLOCK_SIZE], int arr_len, int arr_pos, char arr2[BLOCK_SIZE], int arr2_len, int arr2_pos, int arr2_cpy);
int mangle_overstrike (char arr[BLOCK_SIZE], int arr_len, int upos, char c);
int mangle_truncate_at (char arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_replace (char arr[BLOCK_SIZE], int arr_len, char oldc, char newc);
int mangle_purgechar (char arr[BLOCK_SIZE], int arr_len, char c);
int mangle_dupeblock_prepend (char arr[BLOCK_SIZE], int arr_len, int ulen);
int mangle_dupeblock_append (char arr[BLOCK_SIZE], int arr_len, int ulen);
int mangle_dupechar_at (char arr[BLOCK_SIZE], int arr_len, int upos, int ulen);
int mangle_dupechar (char arr[BLOCK_SIZE], int arr_len);
int mangle_switch_at_check (char arr[BLOCK_SIZE], int arr_len, int upos, int upos2);
int mangle_switch_at (char arr[BLOCK_SIZE], int arr_len, int upos, int upos2);
int mangle_chr_shiftl (uint8_t arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_chr_shiftr (uint8_t arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_chr_incr (uint8_t arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_chr_decr (uint8_t arr[BLOCK_SIZE], int arr_len, int upos);
int mangle_title (char arr[BLOCK_SIZE], int arr_len);
int generate_random_rule (char rule_buf[RP_RULE_BUFSIZ], uint32_t rp_gen_func_min, uint32_t rp_gen_func_max);
int apply_rule_cpu (char *rule, int rule_len, char in[BLOCK_SIZE], int in_len, char out[BLOCK_SIZE]);
int cpu_rule_to_gpu_rule (char rule_buf[BUFSIZ], uint rule_len, gpu_rule_t *rule);

typedef int bool;

bool class_num (char c);
bool class_lower (char c);
bool class_upper (char c);
bool class_alpha (char c);
char conv_ctoi (char c);
char conv_itoc (char c);

uint get_random_num (uint min, uint max);

void gen_cmask (const uint8_t *word, uint8_t *cmask, const uint len);

#endif
