extern crate avro_rs;

#[macro_use]
extern crate serde_derive;
extern crate failure;
extern crate base64;

use avro_rs::{Codec, Schema, Writer, from_value, Reader, types::Record};
use failure::Error;
use std::vec::Vec;
use std::fs;
use std::io;
use base64::{encode, decode};
use parity_snappy as snappy;

#[derive(Debug, Deserialize, Serialize)]
struct Test {
   a: i64,
   b: String,
   link: String 
}

fn main() -> Result<(), Error> {
    
    let raw_schema = r#"
        {
            "type": "record",
            "name": "test",
            "fields": [               
                {"name": "a", "type": "int"},
                {"name": "b", "type": "int"},
                {"name": "c", "type": "int"}
            ]
        }
    "#;

    let schema = Schema::parse_str(raw_schema)?;
    
    let mut writer = Writer::with_codec(&schema, Vec::new(), Codec::Null);
    let mut record = Record::new(writer.schema()).unwrap();
    record.put("a", 20);
    record.put("b", 30);
    record.put("c", 40);

    writer.append(record)?;

    writer.flush()?;
    
    let input = writer.into_inner();
    let comped = snappy::compress(&input);
    print_to_file(input);
    read_avro_file(schema);
    Ok(())
}

fn read_avro_file(schema: Schema) -> Result<(), Error> {
    let compressed = fs::read("avroData.avro.snappy")?;
    let decompressed = snappy::decompress(&compressed)?;
    let reader = Reader::with_schema(&schema, &decompressed[..])?;
    for record in reader {
        println!("{:?}", from_value::<Test>(&record?));
    }
    Ok(())
} 

fn print_to_file(avroData: Vec<u8>) {
    fs::write("avroData.avro.snappy", &avroData);
}

