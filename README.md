# EE739-SuperScalar
## rob
Uses the less risky, cheaper, conservative flushing method for misprediction of branches.
## rob_alt
Uses the more customised method for flushing as soon as misprediction is noticed.
`There is speculation that this might not be synthesizable so we have stopped any updates on this`

## store_buffer
Design policy:

1.  It should take in addr and data at dispatch only cause ROB never gets the data or addr

2.  Then it gets the valid addr from pipeline

3.  Ideally it should have gotten valid data at dispatch itself (but if scheduler is aggressive, we can just send it the RRF pointer and then hope that store buffer gets the valid data after pipeline screams it out at a later stage)

4.  Then it just waits for ROB to actually "retire" it. Until then, it is prone to getting flushed out of speculation

5.  Once it is "retired" (or finished), we just now wait for the memory port to be freed up

6.  Any loads can just access data from Store Buffer if the finished bit is one
