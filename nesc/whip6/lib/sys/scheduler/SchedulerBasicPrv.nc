/*
 * Copyright (c) 2000-2003 The Regents of the University  of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE
 * file. to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA,
 * 94704.  Attention:  Intel License Inquiry.
 *
 *
 * whip6: Warsaw High-performance IPv6.
 *
 * Copyright (c) 2012-2017 Przemyslaw Horban
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached LICENSE     
 * files.
 */
 
/**
 * SchedulerBasicPrv implements the default TinyOS scheduler sequence, as
 * documented in TEP 106.
 *
 * @author Philip Levis
 * @author Cory Sharp
 * @author Przemyslaw Horban
 * @date   January 19 2005
 */

#include <string.h>

module SchedulerBasicPrv @safe() {
    provides interface Scheduler;
    provides interface TaskBasic[uint8_t id];
    uses interface McuSleep;
    uses interface Init as TaskPostedHook;
}
implementation
{
    enum
    {
        NUM_TASKS = uniqueCount("TinySchedulerPub.TaskBasic"),
        NO_TASK = 255,
    };

    volatile uint8_t m_head;
    volatile uint8_t m_tail;
    volatile uint8_t m_next[NUM_TASKS];

    // For debug purposes. Allows you to check which task led to a hang.
    volatile uint8_t m_currentTaskNr;

    // Helper functions (internal functions) intentionally do not have atomic
    // sections.  It is left as the duty of the exported interface functions to
    // manage atomicity to minimize chances for binary code bloat.

    // move the head forward
    // if the head is at the end, mark the tail at the end, too
    // mark the task as not in the queue
    inline uint8_t popTask()
    {
        if( m_head != NO_TASK )
        {
            uint8_t id = m_head;
            m_head = m_next[m_head];
            if( m_head == NO_TASK )
            {
                m_tail = NO_TASK;
            }
            m_next[id] = NO_TASK;
            return id;
        }
        else
        {
            return NO_TASK;
        }
    }

    bool isWaiting( uint8_t id )
    {
        return (bool)((m_next[id] != NO_TASK) || (m_tail == id));
    }

    bool pushTask( uint8_t id )
    {
        if( !isWaiting(id) )
        {
            if( m_head == NO_TASK )
            {
                m_head = id;
                m_tail = id;
            }
            else
            {
                m_next[m_tail] = id;
                m_tail = id;
            }
            return TRUE;
        }
        else
        {
            return FALSE;
        }
    }

    command void Scheduler.init()
    {
        atomic
        {
            memset( (void *)m_next, NO_TASK, sizeof(m_next) );
            m_head = NO_TASK;
            m_tail = NO_TASK;
        }
    }

    command bool Scheduler.runNextTask()
    {
        uint8_t nextTask;
        atomic
        {
            nextTask = popTask();
            if( nextTask == NO_TASK )
            {
                return FALSE;
            }
        }
        m_currentTaskNr = nextTask;
        signal TaskBasic.runTask[nextTask]();
        return TRUE;
    }

    command void Scheduler.taskLoop()
    {
        for (;;)
        {
            uint8_t nextTask;

            atomic {
                /* Using a while loop here would be incorrect, as it may lead
                 * to an infinite loop with interrupts disabled if McuSleep.sleep
                 * decides that sleeping is not allowed (for example because one
                 * of the drivers disallowed it).
                 */
                if ((nextTask = popTask()) == NO_TASK)
                {
                    /* This call should, according to the interface
                     * specification, atomically enable interrupts and
                     * go to sleep, that is if an interrupt becomes pending
                     * while going to sleep, sleep should be cancelled.
                     */
                    call McuSleep.sleep();
                }
            }

            if (nextTask != NO_TASK) {
                m_currentTaskNr = nextTask;
                signal TaskBasic.runTask[nextTask]();
            }
        }
    }

    /**
     * Return SUCCESS if the post succeeded, EBUSY if it was already posted.
     */

    async command error_t TaskBasic.postTask[uint8_t id]()
    {
        error_t rv;
        atomic { rv = pushTask(id) ? SUCCESS : EBUSY; }
        if (rv == SUCCESS) {
            call TaskPostedHook.init();
        }
        return rv;
    }

    default event void TaskBasic.runTask[uint8_t id]()
    {
    }

    default command error_t TaskPostedHook.init()
    {
        return SUCCESS;
    }
}
