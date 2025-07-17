import system

main:
  task:: 
    while true:
      stats := system.process-stats --gc=false

      allocated_memory := stats[STATS-INDEX-ALLOCATED-MEMORY]
      reserved_memory := stats[STATS-INDEX-RESERVED-MEMORY]
      system_free_memory := stats[STATS-INDEX-SYSTEM-FREE-MEMORY]
      largest_free_area := stats[STATS-INDEX-SYSTEM-LARGEST-FREE]
      bytes_allocated := stats[STATS-INDEX-BYTES-ALLOCATED-IN-OBJECT-HEAP]
      gc_count := stats[STATS-INDEX-GC-COUNT]
      full_gc_count := stats[STATS-INDEX-FULL-GC-COUNT]
      full_compacting_gc_count := stats[STATS-INDEX-FULL-COMPACTING-GC-COUNT]

      heap_utilization := (allocated_memory / reserved_memory)

      free_heap := reserved_memory - allocated_memory
      fragmentation_ratio := (largest_free_area / free_heap)

      print "=== Memory and GC Statistics ==="
      print "Allocated Memory (bytes):       $(allocated_memory)"
      print "Reserved Memory (bytes):        $(reserved_memory)"
      print "Heap Utilization:               $((heap_utilization * 100).stringify 3)"
      print "System Free Memory (bytes):     $(system_free_memory)"
      print "Largest Free Area (bytes):      $(largest_free_area)"
      print "Fragmentation Ratio:            $(fragmentation_ratio)"
      print "Bytes Allocated in Object Heap: $(bytes_allocated)"
      print "GC Count (new-space):           $(gc_count)"
      print "Full GC Count:                  $(full_gc_count)"
      print "Full Compacting GC Count:       $(full_compacting_gc_count)"
      sleep --ms=10000