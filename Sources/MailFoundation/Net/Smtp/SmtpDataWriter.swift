//
// SmtpDataWriter.swift
//
// Helpers for SMTP DATA dot-stuffing and termination.
//

public enum SmtpDataWriter {
    private static let cr: UInt8 = 0x0D
    private static let lf: UInt8 = 0x0A
    private static let dot: UInt8 = 0x2E

    public static func prepare(_ data: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(data.count + 5)

        var atLineStart = true
        for byte in data {
            if atLineStart, byte == dot {
                output.append(dot)
            }
            output.append(byte)
            if byte == lf {
                atLineStart = true
            } else if byte != cr {
                atLineStart = false
            }
        }

        let terminator: [UInt8] = [cr, lf, dot, cr, lf]
        if output.count >= terminator.count, Array(output.suffix(terminator.count)) == terminator {
            return output
        }

        if output.count >= 2, Array(output.suffix(2)) == [cr, lf] {
            output.append(contentsOf: [dot, cr, lf])
        } else {
            output.append(contentsOf: terminator)
        }

        return output
    }
}
