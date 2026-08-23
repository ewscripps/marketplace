// queue.js -- tiny-svc in-memory job queue.
//
// A minimal FIFO used to hand accepted webhook payloads from the API layer
// to the worker processor. There is no persistence: a process restart
// silently drops every queued job. That is a known gap but is not one of
// the six counted in ../../expected.json (it is out of scope for this
// fixture's intentionally small gap set -- see that file's header).

const jobs = [];

function enqueue(job) {
  jobs.push(job);
}

function dequeue() {
  return jobs.shift();
}

function size() {
  return jobs.length;
}

module.exports = { enqueue, dequeue, size };
