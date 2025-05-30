# EE739-SuperScalar
## rob
Uses the less risky, cheaper, conservative flushing method for misprediction of branches.
## rob_alt
Uses the more customised method for flushing as soon as misprediction is noticed.

`There is speculation that this might not be synthesizable so we have stopped any updates on this`

## store_buffer
Design policy:

1.  It should take in PC and data (valid or not) at dispatch only cause ROB never gets the data or addr

2.  Then it gets the valid addr from pipeline

3.  Ideally it should have gotten valid data at dispatch itself (but if scheduler is aggressive, we can just send it the RRF pointer and then hope that store buffer gets the valid data after pipeline screams it out at a later stage)

4.  Then it just waits for ROB to actually "retire" it. Until then, it is prone to getting flushed out of speculation.

5.  Once it is "retired" (or finished),

    1.  We put the finished bit to '1'

    2.  Check the load queue for any aliases; if so, mark them as speculative.

    3.  Wait for the memory port to be freed up

6.  Any loads can just access data from Store Buffer if the finished bit is one. Any loads can infer load bypassing from Store Buffer if the mem addr is valid.

## load_queue
Design policy:

1.  Load queue should take the rrf addr and PC during dispatch.

2.  At the end of execution, after tag matching, we get the address we want to pull data from.

3.  We first search through the store buffer to see if there are any aliases. If the finished bit is '1', we just do load forwarding and make the `forwarded` bit = '1'. Else, we will have to keep the `quenched` bit = '0' and try to forward in the next cycle. Do this for all the `quenched` = '0' rows.

4. When we get a alias-checker tag, we just make the `speculation` bit = '1' if there is any mem addr match when the `forward` bit = '0'. If no matches, we can safely ignore the alias-checker.

5. When a load instruction reaches the top of ROB, we will check if `head` has `spec` bit = '1'. If so, flush the load queue as well as the ROB.

## load_queue (new) (slightly out of date)
Design policy:

1. The queue is a table in which theres a busy bit which tells if a particular location in the table is free or not.

2. It takes the Pc addr during dispatch if theres a valid load instr. It finds the first non-busy location  that it can, and stores the pc addr there.

3. Then it sees if theres a need to flush. If so, then make the busy bit of every row `0`, so thats sorted.

4. Then it takes value from execute, and if it finds a pc_addr corresponding, then it stores the calculated mem_addr there. It also stores a bit which tells if the pipeline has done forwarding.

5. Next it checks for aliasing, if it finds a corresponding pc_addr, and forwarding wasn't done, then it makes the `alias` bit 1.

6. Then it sees if there is a load instr at the top of ROB. If so, it checks whether the corresponding location in load_queue was aliased. If it was, then it tells this to the ROB.

7. Lastly, if the ROB tells that a load instr was safely retired, load_queue makes the corresponding location ka busy bit 0, essentially making the row empty.

## Memory and Memory Arbiter

1. From LS pipeline, arbiter gets a signal for load request, and an address. It gets back the data from mem and sends to LS pipeline. This is asynchronous so chill.

2. For store buffer: when ls_pipeline is not asking for data, the port_is_free bit is set to high. Then, if store_buffer wants to store something, it sends a request along with address and data to arbiter, which is forwarded to memory asynchronously.
