"""
Used to modify the digest_data of expected packets:
 - compute the flow_id of the packets
 - modify the digest_data.tuser field
"""

def compute_tuple(ip_src, ip_dst, protocol, src_port, dst_port): # 32 - 32 - 8 - 16 - 16 bits
    ip_src = ip_src.split('.')      # 32 bits
    ip_dst = ip_dst.split('.')      # 32 bits
    string = '{:08b}{:08b}{:08b}{:08b}{:08b}{:08b}{:08b}{:08b}{:08b}{:016b}{:016b}'.format(
        int(ip_src[0]),
        int(ip_src[1]),
        int(ip_src[2]),
        int(ip_src[3]),
        int(ip_dst[0]),
        int(ip_dst[1]),
        int(ip_dst[2]),
        int(ip_dst[3]),
        protocol,
        src_port,
        dst_port)
    return int(string, 2)


# [7:0]    cache_write; // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
# [15:8]   cache_read;  // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
# [23:16]  cache_drop;  // encoded:  {0, 0, 0, DMA, NF3, NF2, NF1, NF0}
# [31:24]  cache_count; // number of packets to read or drop;
# [79:32]  unused 
def compute_tuser(count, drop, read, write): # binary representation of the four cache_actions
    string = '{:08b}{:08b}{:08b}{:08b}'.format(count, drop, read, write).zfill(80)
    return int(string, 2)


if __name__ == "__main__":
    ip_src = '10.0.0.1'
    ip_dst = '10.0.0.2'
    src_port = 55
    dst_port = 75
    print(compute_tuple(ip_src, ip_dst, 6, src_port, dst_port))
    test = 0b00001100
    print(compute_tuser(3, 0b00000001, 0b00000000, 0b111111111))