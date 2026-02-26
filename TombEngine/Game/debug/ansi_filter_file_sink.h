#pragma once
#include <spdlog/sinks/sink.h>
#include <spdlog/sinks/basic_file_sink.h>
#include <regex>
#include <memory>

namespace TEN::Debug
{
    // Sink that filters ANSI sequences before writing to file
    class ansi_filter_file_sink : public spdlog::sinks::sink
    {
        public:
            ansi_filter_file_sink(const std::string& filename, bool truncate)
                : file_sink_(std::make_shared<spdlog::sinks::basic_file_sink_mt>(filename, truncate)) {}

            void log(const spdlog::details::log_msg& msg) override
            {
                spdlog::memory_buf_t filtered_buf;
                std::string s(msg.payload.data(), msg.payload.size());
                static const std::regex ansi_regex("\x1B\\[[0-9;?]*[ -/]*[@-~]");
                s = std::regex_replace(s, ansi_regex, "");
                filtered_buf.append(s.data(), s.data() + s.size());
                spdlog::details::log_msg filtered_msg = msg;
                filtered_msg.payload = spdlog::string_view_t(filtered_buf.data(), filtered_buf.size());
            file_sink_->log(filtered_msg);
            }

            void flush() override
            {
                file_sink_->flush();
            }

            void set_pattern(const std::string& pattern) override
            {
                file_sink_->set_pattern(pattern);
            }

            void set_formatter(std::unique_ptr<spdlog::formatter> sink_formatter) override
            {
                file_sink_->set_formatter(std::move(sink_formatter));
            }

        private:
            std::shared_ptr<spdlog::sinks::basic_file_sink_mt> file_sink_;
    };
} // namespace TEN::Debug