atomic.benchmark = atomic.benchmark or {}

local Instant = atomic.time.newInstant
local Duration = atomic.time.newDuration

---@class Atomic.BenchmarkResult
---@field iterations Atomic.Time.Duration[]
---@field average Atomic.Time.Duration
---@field min Atomic.Time.Duration
---@field max Atomic.Time.Duration

---@param func function
---@param opts? { repeats: number, warmup: number }
---@return Atomic.BenchmarkResult
function atomic.benchmark.run(func, opts)
  opts = opts or { repeats = 1, warmup = 2 }
  local repeats = opts.repeats or 1
  local warmup = opts.warmup or 2

  -- warmup
  for i = 1, warmup do
    func()
  end

  local iterations = {}

  -- benchmark
  for i = 1, repeats do
    local start = Instant()
    func()
    iterations[#iterations+1] = start:elapsed()
  end

  -- statistic
  local min = iterations[1]
  local max = iterations[1]
  local sum = Duration(0, 0)

  for i = 1, #iterations do
    local v = iterations[i]
    if v < min then min = v end
    if v > max then max = v end
    sum = sum + v
  end

  local average = sum / #iterations

  return {
    iterations = iterations,
    min = min,
    max = max,
    average = average
  }
end