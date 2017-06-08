/*
 * whip6: Warsaw High-performance IPv6.
 *
 * Copyright (c) University of Warsaw
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached LICENSE     
 * files.
 */

/**
 * @author Szymon Acedanski
 *
 * CC2538 uDMA channel.
 * 
 * For API information, see:
 *
 * Peripheral Driver Library,
 * Texas Instruments CC2538 Family of Products,
 * User’s Guide,
 * section 18.
 */

interface DMAChannel {
    async command bool intStatus();
    async command void clearInt();

    command void controlSet(uint32_t control);
    command void transferSet(uint32_t mode, void* srcAddr, void* dstAddr,
            uint32_t transferSize);

    command void enable();
    command bool isEnabled();
    command void disable();
}
