module AnsiCodes

const CSI = "\e["


cursor_up!(io::IO, n=1) = print(io, CSI, n, 'A')
cursor_down!(io::IO, n=1) = print(io, CSI, n, 'B')

cursor_horizontal_absolute!(io::IO, n=1) = print(io, CSI, n, 'G')

@enum EraseLineMode begin
    CURSOR_TO_END = 0
    CURSOR_TO_BEGINNING = 1
    ENTIRE_LINE = 2
end
erase_line!(io::IO, mode::EraseLineMode=ENTIRE_LINE) = print(io, CSI, Int(mode), 'K')

end