/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// This include is relative to $CARAVEL_PATH (see Makefile)
#include <defs.h>
#include <stub.c>

/*
    TODO description
*/

#define USER_PROJECT_BASE 0x30000000

void main()
{

    /* 
    IO Control Registers
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 3-bits | 1-bit | 1-bit | 1-bit  | 1-bit  | 1-bit | 1-bit   | 1-bit   | 1-bit | 1-bit | 1-bit   |
    Output: 0000_0110_0000_1110  (0x1808) = GPIO_MODE_USER_STD_OUTPUT
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 110    | 0     | 0     | 0      | 0      | 0     | 0       | 1       | 0     | 0     | 0       |
    
     
    Input: 0000_0001_0000_1111 (0x0402) = GPIO_MODE_USER_STD_INPUT_NOPULL
    | DM     | VTRIP | SLOW  | AN_POL | AN_SEL | AN_EN | MOD_SEL | INP_DIS | HOLDH | OEB_N | MGMT_EN |
    | 001    | 0     | 0     | 0      | 0      | 0     | 0       | 0       | 0     | 1     | 0       |
    */

    /* Set up the housekeeping SPI to be connected internally so    */
    /* that external pin changes don't affect it.            */

    reg_spi_enable = 1;
    reg_wb_enable = 1;

    // Now, apply the configuration
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);
    
    // Configure LA probes as: cpu -> user_project
    reg_la0_oenb = reg_la0_iena = 0xFFFFFFFF;    // [31:0]
    reg_la1_oenb = reg_la1_iena = 0xFFFFFFFF;    // [63:32]
    reg_la2_oenb = reg_la2_iena = 0xFFFFFFFF;    // [95:64]
    reg_la3_oenb = reg_la3_iena = 0xFFFFFFFF;    // [127:96]

    // Reset all LA probes
    reg_la0_data = 0x00000000;
    reg_la1_data = 0x00000000;
    reg_la2_data = 0x00000000;
    reg_la3_data = 0x00000000;

    // Deassert reset on LeoRV Cores
    reg_la0_data = 1;
    
    // Assert reset on LeoRV Cores
    reg_la0_data = 0;

    // Write to memory (bytes)
    for (int i=0; i<=0xF; i++)
    {
        *(((volatile uint8_t*)USER_PROJECT_BASE) + i) = i;
    }
    
    // Write to memory (words)
    for (int i=4; i<10*4; i++)
    {
        *(((volatile uint32_t*)USER_PROJECT_BASE) + i) = 0;
    }
    
    // Read from memory
    *(((volatile uint32_t*)USER_PROJECT_BASE) + 0xA) = *(((volatile uint32_t*)USER_PROJECT_BASE) + 0);
    *(((volatile uint32_t*)USER_PROJECT_BASE) + 0xD) = *(((volatile uint32_t*)USER_PROJECT_BASE) + 2);
    *(((volatile uint8_t*) USER_PROJECT_BASE) + 62 ) = *(((volatile uint32_t*)USER_PROJECT_BASE) + 1);

    // Switch RAM port
    reg_la0_data = 2;

    // This should not get written
    *((volatile uint32_t*)0x30000000) = 0xDEADBEEF;

    // Deassert reset on LeoRV Cores and Switch RAM port
    reg_la0_data = 3;

}
