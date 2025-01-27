local utils = require("vim-apm.utils")
local motion_parser = require("vim-apm.reporter.motion_parser")
local RingBuffer = require("vim-apm.ring_buffer")

---@class APMStatsJson
---@field time_in_insert number
---@field time_in_insert_count number
---@field time_to_insert number
---@field time_to_insert_count number
---@field motions number
---@field write_count number
---@field buf_enter_count number
---@field mode_times number

---@class APMCalculator
---@field motions APMRingBuffer
---@field motions_count table<string>
---@field index_count number
---@field max number
---@field apm_sum number
---@field apm_period number
---@field apm_repeat_count number
local APMCalculator = {}
APMCalculator.__index = APMCalculator

function APMCalculator.new(apm_repeat_count, apm_period)
    return setmetatable({
        motions = RingBuffer.new(),
        motions_count = {},
        index_count = 1,
        apm_sum = 0,
        apm_period = apm_period,
        apm_repeat_count = apm_repeat_count,
    }, APMCalculator)
end

function APMCalculator:trim()
    local expired = utils.now() - self.apm_period
    while self.motions:peek() ~= nil do
        local item = self.motions:peek()
        if item[1] < expired then
            self.motions:pop()
            self.apm_sum = math.max(0, utils.normalize_number(self.apm_sum - item[2]))
        else
            break
        end
    end
end

---@param motion APMMotionItem
---@return number
function APMCalculator:push(motion)
    local key = motion_parser.disnumber_motion(motion.chars)
    local now = utils.now()

    local count = 1
    for i = 1, self.apm_repeat_count do
        local other_motion = self.motions_count[i]
        if other_motion == key then
            count = count + 1
        end
    end

    self.motions_count[self.index_count] = key
    self.index_count = self.index_count + 1
    if self.index_count > self.apm_repeat_count then
        self.index_count = 1
    end

    local apm_score = utils.normalize_number(1 / count)

    self.motions:push({now, apm_score})
    self.apm_sum = self.apm_sum + apm_score
    self:trim()

    return apm_score
end

---@class APMAggregateMotionValue
---@field count number
---@field timings_total number

---@class APMStats
---@field motions table<string, APMAggregateMotionValue>
---@field write_count number
---@field _time_to_insert number
---@field _time_to_insert_count number
---@field _time_in_insert number
---@field _time_in_insert_count number
---@field buf_enter_count number
---@field mode_times table<string, number>
---@field last_mode string
---@field last_mode_start_time number
---@field state string
local Stats = {}
Stats.__index = Stats

function Stats.new()
    return setmetatable({
        motions = {},
        write_count = 0,
        time_to_insert = 0,
        time_to_insert_count = 0,
        time_in_insert = 0,
        time_in_insert_count = 0,
        buf_enter_count = 0,
        mode_times = {},
        last_mode = "n",
        last_mode_start_time = utils.now(),
        state = "",
    }, Stats)
end

---@param json APMStatsJson
---@return APMStats
function Stats.from_json(json)
    return setmetatable({
        motions = json.motions,
        write_count = json.write_count,
        time_to_insert = json.time_to_insert,
        time_to_insert_count = json.time_to_insert_count,
        time_in_insert = json.time_in_insert,
        time_in_insert_count = json.time_in_insert_count,
        buf_enter_count = json.buf_enter_count,
        mode_times = json.mode_times,

        last_mode = "n",
        last_mode_start_time = utils.now(),
        state = "",
    }, Stats)
end

function Stats:enable()
end

function Stats:clear()
    self.motions = {}
    self.write_count = 0
    self.buf_enter_count = 0
    self._time_to_insert = 0
    self._time_to_insert_count = 0
    self._time_in_insert = 0
    self._time_in_insert_count = 0
    self.mode = {}
end

---@param motion APMMotionItem
function Stats:motion(motion)
    local key = motion_parser.generate_motion_key(motion.chars)
    local sum = 0
    for _, timing in ipairs(motion.timings) do
        sum = sum + timing
    end

    self.motions[key] = self.motions[key] or {
        count = 1,
        timings_total = sum
    }
    self.motions[key].count = self.motions[key].count + 1
    self.motions[key].timings_total = self.motions[key].timings_total + sum
end

---@param mode string
function Stats:mode(mode)
    local now = utils.now()
    local time_in_last_mode = now - self.last_mode_start_time
    local last_mode = self.last_mode

    self.mode_times[last_mode] = time_in_last_mode
    self.last_mode_start_time = now
    self.last_mode = mode
end

function Stats:buf_enter()
    self.buf_enter_count = self.buf_enter_count + 1
end

function Stats:write()
    self.write_count = self.write_count + 1
end

---@param insert_time number
function Stats:time_to_insert(insert_time)
    self.time_to_insert = self.time_to_insert + insert_time
    self.time_to_insert_count = self.time_to_insert_count + 1
end

--- Another placeholder for when i try to calculate the wpm
---@param time_in_insert number time spent in insert mode
---@param count number
function Stats:time_in_insert(time_in_insert, count)
    self._time_in_insert = self._time_in_insert + time_in_insert
    self._time_in_insert_count = self._time_in_insert_count + count
end

--- this is a placeholder for when i have navigating / editing / idle states
--- as of now, it does nothing to the calculator
---@param state string
function Stats:apm_state(state)
    self.state = state
end

---@returns APMStatsJson
function Stats:to_json()
    self:mode(self.last_mode)

    return {
        time_in_insert = self._time_in_insert,
        time_in_insert_count = self._time_in_insert_count,
        time_to_insert = self.time_to_insert,
        time_to_insert_count = self.time_to_insert_count,

        motions = self.motions,
        write_count = self.write_count,
        buf_enter_count = self.buf_enter_count,

        mode_times = self.mode_times,
    }
end

return {
    Stats = Stats,
    APMCalculator = APMCalculator,
}
